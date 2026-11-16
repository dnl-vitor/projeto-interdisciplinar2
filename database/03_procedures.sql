-- =============================================================================
--  GIE_DATA  |  PROCEDURES  (rodar depois de 02_views.sql)
--
--  Execute este arquivo com o cliente `mysql` (ele usa DELIMITER).
--  No PHP/PDO, só CHAMAR as procedures:  $pdo->query("CALL sp_...(...)").
--
--  Procedures:
--    sp_irrigar_area(area, caixa, minutos, tipo, usuario)   -> UC03
--    sp_irrigacao_automatica(garden)                        -> Sistema (Automático)
--    sp_alertas_sincronizar(garden)       (interna)         -> UC04
--    sp_verificar_alertas(garden)                           -> UC04 + lista
--    sp_gerar_relatorio(garden, usuario, tipo, inicio, fim) -> UC05
--    sp_alertas_sincronizar_todos() / sp_gerar_relatorio_agendado() (p/ eventos)
--
--  Entrada de dados que NÃO precisa de procedure (triggers cuidam):
--    INSERT em leitura_sensor     -> atualiza sensor e volume da caixa  (UC "telemetria")
--    INSERT em registro_consumo   -> valida e abate estoque             (UC02)
--    INSERT em entrada_insumo     -> repõe estoque
--    INSERT em registro_perda     -> abate do estágio
-- =============================================================================
USE GIE_DATA;

DROP PROCEDURE IF EXISTS sp_irrigar_area;
DROP PROCEDURE IF EXISTS sp_irrigacao_automatica;
DROP PROCEDURE IF EXISTS sp_alertas_sincronizar;
DROP PROCEDURE IF EXISTS sp_verificar_alertas;
DROP PROCEDURE IF EXISTS sp_gerar_relatorio;
DROP PROCEDURE IF EXISTS sp_alertas_sincronizar_todos;
DROP PROCEDURE IF EXISTS sp_gerar_relatorio_agendado;

DELIMITER $$

-- =============================================================================
-- UC03 — Acionar Irrigação de Precisão
--   p_tipo   : 'automatico' | 'manual' | 'forcado'
--   p_minutos: tempo MÁXIMO (manual/automatico, pode ser NULL = sem limite)
--              ou tempo EXATO (forcado, obrigatório)
--   p_usuario: NULL quando o acionamento é do Sistema
--
--   manual/automatico: irriga o volume ideal da área (limitado pela água da caixa
--                      e pelo tempo máximo).
--   forcado:           ignora necessidade e volume ideal; irriga pelo tempo
--                      informado (limitado apenas pela água disponível).
--
--   Correções em relação ao Java: o tempo não é mais truncado para minutos
--   inteiros (com vazão 8 L/min e necessidade de 5 L o Java irrigava 0 min), e
--   o modo "forçado" realmente ignora o cálculo ideal.
-- =============================================================================
CREATE PROCEDURE sp_irrigar_area(
  IN p_area    INT,
  IN p_caixa   INT,
  IN p_minutos DOUBLE,
  IN p_tipo    VARCHAR(10),
  IN p_usuario INT
)
BEGIN
  DECLARE v_garden_area  INT;
  DECLARE v_garden_caixa INT;
  DECLARE v_ligado   TINYINT;
  DECLARE v_vazao    DOUBLE;
  DECLARE v_vol      DOUBLE;
  DECLARE v_cap      DOUBLE;
  DECLARE v_sensor   INT;
  DECLARE v_hmax     DOUBLE;
  DECLARE v_necess   DOUBLE;
  DECLARE v_agua     DOUBLE;
  DECLARE v_min      DOUBLE;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_tipo NOT IN ('automatico','manual','forcado') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de acionamento invalido (automatico, manual ou forcado).';
  END IF;

  START TRANSACTION;

  SELECT fk_id_garden INTO v_garden_area FROM area WHERE id_area = p_area;
  IF v_garden_area IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Area nao encontrada.';
  END IF;

  -- trava a caixa para dois acionamentos simultâneos não gastarem a mesma água
  SELECT c.fk_id_garden, c.vol_atual, c.cap_l, c.fk_id_sensor_nivel
    INTO v_garden_caixa, v_vol, v_cap, v_sensor
    FROM caixa_dagua c WHERE c.id_caixa = p_caixa FOR UPDATE;
  IF v_garden_caixa IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Caixa d''agua nao encontrada.';
  END IF;
  IF v_garden_caixa <> v_garden_area THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A caixa nao pertence a estufa da area.';
  END IF;

  SELECT si.lig_bol, si.vazao_l INTO v_ligado, v_vazao
    FROM garden g JOIN sistema_irrigacao si ON si.id_sis_irr = g.fk_id_sist_irriga
   WHERE g.id_garden = v_garden_area;

  IF v_ligado = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sistema de irrigacao desligado.';
  END IF;
  IF v_vol <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Caixa d''agua sem agua.';
  END IF;

  IF p_tipo = 'forcado' THEN
    IF p_minutos IS NULL OR p_minutos <= 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Irrigacao forcada exige o tempo em minutos.';
    END IF;
    SET v_agua = LEAST(v_vazao * p_minutos, v_vol);
  ELSE
    SELECT volume_ideal_l INTO v_necess FROM vw_area_parametros WHERE id_area = p_area;
    IF v_necess <= 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Area sem plantas: nao ha volume ideal a irrigar.';
    END IF;
    SET v_agua = LEAST(v_necess, v_vol, IF(p_minutos IS NULL, v_necess, v_vazao * p_minutos));
  END IF;

  SET v_min = ROUND(v_agua / v_vazao, 2);

  INSERT INTO hist_irrigacao
        (fk_id_area, fk_id_caixa, fk_id_usuario, tempo_efetivo_min, agua_usada_l, tipo_acionamento)
  VALUES (p_area, p_caixa, p_usuario, v_min, v_agua, p_tipo);

  -- registra o novo nível como leitura 'sistema'; o trigger atualiza vol_atual
  SELECT h_max INTO v_hmax FROM sensor_nivel WHERE id_sensor_controle = v_sensor;
  INSERT INTO leitura_sensor (fk_id_sensor, valor, origem, fk_id_usuario)
  VALUES (v_sensor, GREATEST(0, (v_vol - v_agua) / v_cap * v_hmax), 'sistema', p_usuario);

  COMMIT;

  SELECT v_agua AS litros, v_min AS minutos, p_tipo AS tipo_acionamento,
         IF(p_tipo = 'forcado', 'Irrigacao forcada na area', 'Irrigado') AS mensagem,
         (SELECT vol_atual FROM caixa_dagua WHERE id_caixa = p_caixa) AS volume_restante_l;
END$$

-- =============================================================================
-- Sistema (Automático): irriga toda área 'seca' da estufa, usando a caixa com
-- mais água. Erros em uma área (ex.: sistema desligado) não param as demais.
-- Não está agendada por padrão em 05_events.sql — habilite só quando quiser
-- irrigação realmente automática.
-- =============================================================================
CREATE PROCEDURE sp_irrigacao_automatica(IN p_garden INT)
BEGIN
  DECLARE v_done  TINYINT DEFAULT 0;
  DECLARE v_area  INT;
  DECLARE v_caixa INT;
  DECLARE cur CURSOR FOR
    SELECT id_area FROM vw_dash_area WHERE fk_id_garden = p_garden AND status_umidade = 'seco';
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  OPEN cur;
  loop_areas: LOOP
    FETCH cur INTO v_area;
    IF v_done = 1 THEN LEAVE loop_areas; END IF;

    SET v_caixa = NULL;
    SELECT id_caixa INTO v_caixa FROM caixa_dagua
     WHERE fk_id_garden = p_garden AND vol_atual > 0
     ORDER BY vol_atual DESC LIMIT 1;

    IF v_caixa IS NOT NULL THEN
      BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;   -- pula a área com erro
        CALL sp_irrigar_area(v_area, v_caixa, NULL, 'automatico', NULL);
      END;
    END IF;
  END LOOP;
  CLOSE cur;
END$$

-- =============================================================================
-- UC04 — Monitorar Alertas: abre os alertas novos e fecha os que se resolveram.
-- (interna: não devolve result set, para poder ser usada dentro de outras)
-- =============================================================================
CREATE PROCEDURE sp_alertas_sincronizar(IN p_garden INT)
BEGIN
  -- fecha o que não é mais verdade
  UPDATE alerta a
     SET a.resolvido_em = NOW()
   WHERE a.fk_id_garden = p_garden
     AND a.resolvido_em IS NULL
     AND NOT EXISTS (SELECT 1 FROM vw_alertas_calculados c
                      WHERE c.id_garden = a.fk_id_garden AND c.chave = a.chave);

  -- abre o que surgiu
  INSERT INTO alerta (fk_id_garden, fk_id_area, tipo, severidade, chave, mensagem)
  SELECT c.id_garden, c.id_area, c.tipo, c.severidade, c.chave, c.mensagem
    FROM vw_alertas_calculados c
   WHERE c.id_garden = p_garden
     AND NOT EXISTS (SELECT 1 FROM alerta a
                      WHERE a.fk_id_garden = c.id_garden AND a.chave_aberta = c.chave);
END$$

CREATE PROCEDURE sp_verificar_alertas(IN p_garden INT)
BEGIN
  CALL sp_alertas_sincronizar(p_garden);
  SELECT id_alerta, tipo, severidade, mensagem, criado_em AS aberto_desde
    FROM alerta
   WHERE fk_id_garden = p_garden AND resolvido_em IS NULL
   ORDER BY FIELD(severidade, 'critico', 'atencao', 'info'), criado_em;
END$$

-- =============================================================================
-- UC05 — Gerar Relatório: grava as abas do dashboard (com data e hora) em rel_*.
--   p_usuario: id de quem gerou; NULL = Sistema (agendado)
--   p_tipo   : 'completo' | 'areas' | 'plantas' | 'irrigacao' | 'sensores'
--              | 'insumos' | 'alertas'
--   p_inicio / p_fim: janela do período (NULL = últimos 30 dias até agora)
--                     usada em consumo de insumos, irrigações e perdas.
--   Tudo ocorre numa transação: ou o relatório sai inteiro, ou não sai.
--   Devolve: id_relatorio e gerado_em.
-- =============================================================================
CREATE PROCEDURE sp_gerar_relatorio(
  IN p_garden  INT,
  IN p_usuario INT,
  IN p_tipo    VARCHAR(20),
  IN p_inicio  DATETIME,
  IN p_fim     DATETIME
)
BEGIN
  DECLARE v_id    BIGINT;
  DECLARE v_agora DATETIME DEFAULT NOW();   -- NOW() é constante dentro da procedure
  DECLARE v_existe INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_tipo NOT IN ('completo','areas','plantas','irrigacao','sensores','insumos','alertas') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de relatorio invalido.';
  END IF;
  SELECT COUNT(*) INTO v_existe FROM garden WHERE id_garden = p_garden;
  IF v_existe = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estufa nao encontrada.';
  END IF;

  SET p_fim    = COALESCE(p_fim, v_agora);
  SET p_inicio = COALESCE(p_inicio, p_fim - INTERVAL 30 DAY);
  IF p_inicio > p_fim THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Periodo invalido: inicio depois do fim.';
  END IF;

  START TRANSACTION;

  -- alertas atualizados antes de fotografar
  CALL sp_alertas_sincronizar(p_garden);

  INSERT INTO relatorio
        (fk_id_garden, fk_id_usuario, tipo, origem, gerado_em, periodo_inicio, periodo_fim,
         garden_nome, usuario_nome, irrigacao_nome, irrigacao_ligada, irrigacao_vazao_l)
  SELECT g.id_garden, p_usuario, p_tipo, IF(p_usuario IS NULL, 'agendado', 'manual'),
         v_agora, p_inicio, p_fim,
         g.nome, (SELECT NULLIF(u.nome_comp, '') FROM usuario u WHERE u.id_usuario = p_usuario),
         si.nome, si.lig_bol, si.vazao_l
    FROM garden g JOIN sistema_irrigacao si ON si.id_sis_irr = g.fk_id_sist_irriga
   WHERE g.id_garden = p_garden;
  SET v_id = LAST_INSERT_ID();

  -- ---- aba Sensores / Ambiente -------------------------------------------------
  IF p_tipo IN ('completo','sensores') THEN
    INSERT INTO rel_sensor
          (fk_id_relatorio, fk_id_sensor, tipo, `local`, area_nome, valor, unidade,
           faixa_min, faixa_max, status, lido_em)
    SELECT v_id, s.id_sensor, s.tipo, s.`local`, s.area_nome, s.valor, s.unidade,
           s.faixa_min, s.faixa_max, s.status, s.lido_em
      FROM vw_dash_sensor s WHERE s.id_garden = p_garden;
  END IF;

  -- ---- aba Irrigação: reservatórios + resumo do período por área ---------------
  IF p_tipo IN ('completo','irrigacao') THEN
    INSERT INTO rel_reservatorio
          (fk_id_relatorio, fk_id_caixa, sensor_local, cap_l, vol_atual_l, nivel_pct,
           limite_alerta_pct, autonomia_min, status)
    SELECT v_id, r.id_caixa, r.sensor_local, r.cap_l, r.vol_atual, r.nivel_pct,
           r.limite_alerta_pct, r.autonomia_min, r.status
      FROM vw_dash_reservatorio r WHERE r.id_garden = p_garden;

    INSERT INTO rel_irrigacao
          (fk_id_relatorio, fk_id_area, area_nome, qtd_irrigacoes, litros_total,
           minutos_total, qtd_forcadas, ultima_irrigacao)
    SELECT v_id, a.id_area, a.nome,
           COUNT(h.id_historico),
           COALESCE(SUM(h.agua_usada_l), 0),
           COALESCE(SUM(h.tempo_efetivo_min), 0),
           CAST(COALESCE(SUM(h.tipo_acionamento = 'forcado'), 0) AS SIGNED),
           MAX(h.data_hora)
      FROM area a
      LEFT JOIN hist_irrigacao h ON h.fk_id_area = a.id_area
                                AND h.data_hora BETWEEN p_inicio AND p_fim
     WHERE a.fk_id_garden = p_garden
     GROUP BY a.id_area, a.nome;
  END IF;

  -- ---- aba Áreas de cultivo ----------------------------------------------------
  IF p_tipo IN ('completo','areas') THEN
    INSERT INTO rel_area
          (fk_id_relatorio, fk_id_area, area_nome, area_m2, qtd_especies, qtd_plantas,
           umidade, umid_min_ideal, umid_max_ideal, status_umidade,
           ph_solo, ph_min_ideal, ph_max_ideal, status_ph, volume_ideal_l, precisa_irrigar)
    SELECT v_id, a.id_area, a.area_nome, a.area_m2, a.qtd_especies, a.qtd_plantas,
           a.umidade, a.umid_min_ideal, a.umid_max_ideal, a.status_umidade,
           a.ph_solo, a.ph_min_ideal, a.ph_max_ideal, a.status_ph, a.volume_ideal_l, a.precisa_irrigar
      FROM vw_dash_area a WHERE a.fk_id_garden = p_garden;
  END IF;

  -- ---- aba Plantas -------------------------------------------------------------
  IF p_tipo IN ('completo','plantas') THEN
    INSERT INTO rel_area_planta
          (fk_id_relatorio, fk_id_area, fk_id_planta, area_nome, planta_nome,
           necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao,
           qtd_plantada, qtd_atual, estagios, data_plantio, perdas_periodo)
    SELECT v_id, d.fk_id_area, d.fk_id_planta, d.area_nome, d.planta_nome,
           d.necessidade_agua, d.necessidade_luz, d.ph_ideal_min, d.ph_ideal_max, d.nutricao,
           d.qtd_plantada, d.qtd_atual, d.estagios, d.data_plantio,
           (SELECT CAST(COALESCE(SUM(rp.quantidade), 0) AS SIGNED) FROM registro_perda rp
             WHERE rp.fk_id_area = d.fk_id_area AND rp.fk_id_planta = d.fk_id_planta
               AND rp.data_hora BETWEEN p_inicio AND p_fim)
      FROM vw_area_planta_detalhe d WHERE d.fk_id_garden = p_garden;
  END IF;

  -- ---- aba Insumos / Estoque ---------------------------------------------------
  IF p_tipo IN ('completo','insumos') THEN
    INSERT INTO rel_insumo
          (fk_id_relatorio, fk_id_insumo, nome_ins, categoria, unidade, estoque, lmt_min,
           consumo_total, consumo_periodo, status)
    SELECT v_id, i.id_insumo, i.nome_ins, i.categoria, i.unidade, i.estoque, i.lmt_min,
           i.consumo_total,
           (SELECT COALESCE(SUM(rc.qtd_aplicada), 0) FROM registro_consumo rc
             WHERE rc.fk_id_insumo = i.id_insumo AND rc.data_hora BETWEEN p_inicio AND p_fim),
           i.status
      FROM vw_dash_insumo i WHERE i.id_garden = p_garden;
  END IF;

  -- ---- aba Alertas (abertos neste instante) ------------------------------------
  IF p_tipo IN ('completo','alertas') THEN
    INSERT INTO rel_alerta
          (fk_id_relatorio, fk_id_alerta, fk_id_area, tipo, severidade, mensagem, aberto_desde)
    SELECT v_id, al.id_alerta, al.fk_id_area, al.tipo, al.severidade, al.mensagem, al.criado_em
      FROM alerta al
     WHERE al.fk_id_garden = p_garden AND al.resolvido_em IS NULL;
  END IF;

  COMMIT;

  SELECT v_id AS id_relatorio, v_agora AS gerado_em, p_tipo AS tipo;
END$$

-- =============================================================================
-- Rotinas para os eventos agendados (05_events.sql)
-- =============================================================================
CREATE PROCEDURE sp_alertas_sincronizar_todos()
BEGIN
  DECLARE v_done TINYINT DEFAULT 0;
  DECLARE v_g INT;
  DECLARE cur CURSOR FOR SELECT id_garden FROM garden;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  OPEN cur;
  lp: LOOP
    FETCH cur INTO v_g;
    IF v_done = 1 THEN LEAVE lp; END IF;
    CALL sp_alertas_sincronizar(v_g);
  END LOOP;
  CLOSE cur;
END$$

CREATE PROCEDURE sp_gerar_relatorio_agendado()
BEGIN
  DECLARE v_done TINYINT DEFAULT 0;
  DECLARE v_g INT;
  DECLARE cur CURSOR FOR SELECT id_garden FROM garden;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  OPEN cur;
  lp: LOOP
    FETCH cur INTO v_g;
    IF v_done = 1 THEN LEAVE lp; END IF;
    CALL sp_gerar_relatorio(v_g, NULL, 'completo', NULL, NULL);
  END LOOP;
  CLOSE cur;
END$$

DELIMITER ;
