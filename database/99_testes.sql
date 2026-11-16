-- =============================================================================
--  GIE  |  TESTES AUTOMÁTICOS DO BANCO
--
--  ATENÇÃO: altera dados! Rode SOMENTE no banco de teste GIE_TEST, carregado
--  com 01..04. O script rodar_testes.sh faz tudo isso e mostra o resultado.
-- =============================================================================
USE GIE_TEST;

DROP TEMPORARY TABLE IF EXISTS t_res;
CREATE TEMPORARY TABLE t_res (n INT AUTO_INCREMENT PRIMARY KEY, teste VARCHAR(110), resultado VARCHAR(4), detalhe VARCHAR(200));

DROP PROCEDURE IF EXISTS t_erro;
DELIMITER $$
-- executa um comando que DEVE falhar com uma mensagem contendo p_esperado
CREATE PROCEDURE t_erro(IN p_teste VARCHAR(110), IN p_sql TEXT, IN p_esperado VARCHAR(100))
BEGIN
  DECLARE v_msg TEXT DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; END;
  SET @t_sql = p_sql;
  PREPARE s FROM @t_sql; EXECUTE s; DEALLOCATE PREPARE s;
  INSERT INTO t_res (teste, resultado, detalhe)
  VALUES (p_teste, IF(v_msg IS NOT NULL AND v_msg LIKE CONCAT('%', p_esperado, '%'), 'PASS', 'FAIL'),
          COALESCE(LEFT(v_msg, 200), 'NAO deu erro'));
END$$
DELIMITER ;

-- referências
SET @g   := (SELECT id_garden FROM garden LIMIT 1);
SET @u   := (SELECT id_usuario FROM usuario WHERE email = 'demo@gie.local');
SET @ar_a := (SELECT id_area FROM area WHERE nome = 'Canteiro A');
SET @ar_b := (SELECT id_area FROM area WHERE nome = 'Canteiro B');
SET @cx  := (SELECT id_caixa FROM caixa_dagua LIMIT 1);
SET @s_niv := (SELECT fk_id_sensor_nivel FROM caixa_dagua WHERE id_caixa = @cx);
SET @s_amb := (SELECT fk_id_sensor_ambiente FROM garden WHERE id_garden = @g);
SET @s_ua := (SELECT fk_id_sensor_umidade FROM area WHERE id_area = @ar_a);
SET @i_enx := (SELECT id_insumo FROM insumo WHERE nome_ins = 'Enxofre');
SET @i_cal := (SELECT id_insumo FROM insumo WHERE nome_ins = 'Calcario');
SET @p_tom := (SELECT id_planta FROM plantas WHERE nome_p = 'Tomate');
SET @p_alf := (SELECT id_planta FROM plantas WHERE nome_p = 'Alface');
SET @p_cac := (SELECT id_planta FROM plantas WHERE nome_p = 'Cacto');
SET @e_ver := (SELECT id_estagio FROM estagio_planta WHERE nome = 'verde');

-- ===== 1. ESTADO INICIAL (seed) ==================================================
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'seed: caixa com 2400 L (1,2 m de 2,5 m x 5000 L)', IF(ABS(vol_atual - 2400) < 0.001, 'PASS', 'FAIL'), vol_atual
  FROM caixa_dagua WHERE id_caixa = @cx;
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'seed: Canteiro A = seco, pH ok (bug do Java corrigido)',
       IF(status_umidade = 'seco' AND status_ph = 'ok' AND precisa_irrigar = 1, 'PASS', 'FAIL'),
       CONCAT(status_umidade, '/', status_ph) FROM vw_dash_area WHERE id_area = @ar_a;
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'seed: faixa de umidade do Canteiro A = interseccao tomate x alface (60-70)',
       IF(umid_min_ideal = 60 AND umid_max_ideal = 70, 'PASS', 'FAIL'), CONCAT(umid_min_ideal, '-', umid_max_ideal)
  FROM vw_dash_area WHERE id_area = @ar_a;

-- ===== 2. TIPOS DE SENSOR (FK composta) e CHECKs ====================================
CALL t_erro('subtipo errado: sensor_umidade apontando p/ sensor de nivel',
  CONCAT('INSERT INTO sensor_umidade (id_sensor_controle, umid_min, umid_max) VALUES (', @s_niv, ', 10, 50)'), 'foreign key');
CALL t_erro('CHECK: planta com pH minimo > maximo',
  "INSERT INTO plantas (nome_p, necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao) VALUES ('X','alta','sol_pleno',8,6,'baixa')", 'ck_plantas_ph');
CALL t_erro('FK: necessidade de agua inexistente',
  "INSERT INTO plantas (nome_p, necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao) VALUES ('Y','enorme','sol_pleno',6,7,'baixa')", 'foreign key');

-- ===== 3. LEITURAS (validação + cache + volume da caixa) =============================
CALL t_erro('leitura de umidade 150% e rejeitada',
  CONCAT('INSERT INTO leitura_sensor (fk_id_sensor, valor) VALUES (', @s_ua, ', 150)'), 'umidade fora');
CALL t_erro('leitura de nivel acima de h_max e rejeitada',
  CONCAT('INSERT INTO leitura_sensor (fk_id_sensor, valor) VALUES (', @s_niv, ', 9)'), 'h_max');

INSERT INTO leitura_sensor (fk_id_sensor, valor) VALUES (@s_niv, 1.25);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'leitura de nivel 1,25 m => caixa 2500 L',
       IF(ABS(vol_atual - 2500) < 0.001, 'PASS', 'FAIL'), vol_atual FROM caixa_dagua WHERE id_caixa = @cx;

INSERT INTO leitura_sensor (fk_id_sensor, valor, data_hora) VALUES (@s_niv, 2.0, NOW() - INTERVAL 1 DAY);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'leitura ATRASADA (de ontem) nao sobrescreve o estado atual',
       IF(ABS(vol_atual - 2500) < 0.001 AND (SELECT ult_leitura FROM sensor_controle WHERE id_sensor_controle = @s_niv) = 1.25, 'PASS', 'FAIL'),
       vol_atual FROM caixa_dagua WHERE id_caixa = @cx;
INSERT INTO leitura_sensor (fk_id_sensor, valor) VALUES (@s_niv, 1.2);   -- volta a 2400 L

-- ===== 4. INSUMOS (UC02) ============================================================
CALL t_erro('consumo maior que o estoque: "Estoque insuficiente"',
  CONCAT('INSERT INTO registro_consumo (qtd_aplicada, motivo, fk_id_insumo, fk_id_area, fk_id_usuario) VALUES (100, ''correcao_ph'', ', @i_enx, ',', @ar_a, ',', @u, ')'), 'Estoque insuficiente de Enxofre');

INSERT INTO registro_consumo (qtd_aplicada, motivo, fk_id_insumo, fk_id_area, fk_id_usuario) VALUES (1, 'correcao_ph', @i_enx, @ar_a, @u);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'consumo de 1 kg: estoque 8,5 -> 7,5 e consumo_total 1,5 -> 2,5',
       IF(estoque = 7.5 AND consumo_total = 2.5, 'PASS', 'FAIL'), CONCAT(estoque, ' / ', consumo_total) FROM insumo WHERE id_insumo = @i_enx;

INSERT INTO registro_consumo (qtd_aplicada, motivo, fk_id_insumo, fk_id_area, fk_id_usuario) VALUES (6.5, 'correcao_ph', @i_enx, @ar_a, @u);
CALL sp_alertas_sincronizar(@g);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'estoque <= minimo abre alerta estoque_baixo',
       IF(COUNT(*) = 1, 'PASS', 'FAIL'), MAX(mensagem) FROM alerta WHERE tipo = 'estoque_baixo' AND resolvido_em IS NULL;

INSERT INTO entrada_insumo (fk_id_insumo, quantidade, fk_id_usuario, observacao) VALUES (@i_enx, 10, @u, 'reposicao');
CALL sp_alertas_sincronizar(@g);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'reposicao de estoque fecha o alerta (resolvido_em preenchido)',
       IF((SELECT estoque FROM insumo WHERE id_insumo = @i_enx) = 11
          AND COUNT(*) = 0
          AND (SELECT COUNT(*) FROM alerta WHERE tipo = 'estoque_baixo' AND resolvido_em IS NOT NULL) = 1, 'PASS', 'FAIL'),
       (SELECT estoque FROM insumo WHERE id_insumo = @i_enx)
  FROM alerta WHERE tipo = 'estoque_baixo' AND resolvido_em IS NULL;

-- ===== 5. IRRIGAÇÃO (UC03) ==========================================================
CALL sp_irrigar_area(@ar_a, @cx, NULL, 'manual', @u);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'irrigacao manual do Canteiro A: 5 L (volume ideal), caixa 2400 -> 2395',
       IF(ABS(h.agua_usada_l - 5) < 0.001 AND ABS(c.vol_atual - 2395) < 0.001 AND ABS(h.tempo_efetivo_min - 0.625) < 0.02, 'PASS', 'FAIL'),
       CONCAT(h.agua_usada_l, ' L / ', h.tempo_efetivo_min, ' min / caixa ', ROUND(c.vol_atual, 3))
  FROM hist_irrigacao h, caixa_dagua c WHERE c.id_caixa = @cx ORDER BY h.id_historico DESC LIMIT 1;

CALL sp_irrigar_area(@ar_a, @cx, 0.25, 'manual', @u);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'tempo maximo de 0,25 min limita a 2 L (vazao 8 L/min)',
       IF(ABS(agua_usada_l - 2) < 0.001, 'PASS', 'FAIL'), agua_usada_l FROM hist_irrigacao ORDER BY id_historico DESC LIMIT 1;

CALL sp_irrigar_area(@ar_a, @cx, 2, 'forcado', @u);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'irrigacao FORCADA de 2 min ignora o volume ideal: 16 L',
       IF(ABS(agua_usada_l - 16) < 0.001 AND tipo_acionamento = 'forcado', 'PASS', 'FAIL'), agua_usada_l
  FROM hist_irrigacao ORDER BY id_historico DESC LIMIT 1;

INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'caixa baixou 23 L no total (5 + 2 + 16)', IF(ABS(vol_atual - 2377) < 0.001, 'PASS', 'FAIL'), ROUND(vol_atual, 3)
  FROM caixa_dagua WHERE id_caixa = @cx;
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'volume da caixa sem ruido de ponto flutuante (arredondado a mL)',
       IF(vol_atual = ROUND(vol_atual, 3), 'PASS', 'FAIL'), vol_atual FROM caixa_dagua WHERE id_caixa = @cx;
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'sensor de nivel acompanhou (leitura de origem "sistema" registrada)',
       IF(COUNT(*) = 3, 'PASS', 'FAIL'), COUNT(*) FROM leitura_sensor WHERE fk_id_sensor = @s_niv AND origem = 'sistema';

CALL t_erro('forcada sem informar o tempo e recusada',
  CONCAT('CALL sp_irrigar_area(', @ar_a, ',', @cx, ', NULL, ''forcado'', ', @u, ')'), 'exige o tempo');
CALL t_erro('tipo de acionamento invalido',
  CONCAT('CALL sp_irrigar_area(', @ar_a, ',', @cx, ', 1, ''turbo'', ', @u, ')'), 'invalido');

UPDATE sistema_irrigacao SET lig_bol = 0;
CALL t_erro('sistema desligado bloqueia a irrigacao',
  CONCAT('CALL sp_irrigar_area(', @ar_a, ',', @cx, ', NULL, ''manual'', ', @u, ')'), 'desligado');
UPDATE sistema_irrigacao SET lig_bol = 1;

INSERT INTO leitura_sensor (fk_id_sensor, valor) VALUES (@s_niv, 0);
CALL t_erro('caixa vazia bloqueia a irrigacao',
  CONCAT('CALL sp_irrigar_area(', @ar_a, ',', @cx, ', NULL, ''manual'', ', @u, ')'), 'sem agua');

-- ===== 6. ALERTAS (UC04) ============================================================
CALL sp_alertas_sincronizar(@g);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'caixa vazia => alerta nivel_baixo CRITICO', IF(COUNT(*) = 1, 'PASS', 'FAIL'), MAX(mensagem)
  FROM alerta WHERE tipo = 'nivel_baixo' AND severidade = 'critico' AND resolvido_em IS NULL;

CALL sp_alertas_sincronizar(@g);
CALL sp_alertas_sincronizar(@g);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'sincronizar 3x nao duplica alertas abertos',
       IF(COUNT(*) = COUNT(DISTINCT chave), 'PASS', 'FAIL'), CONCAT(COUNT(*), ' abertos') FROM alerta WHERE resolvido_em IS NULL;

CALL t_erro('indice unico: 2 alertas abertos com a mesma chave sao impossiveis',
  CONCAT('INSERT INTO alerta (fk_id_garden, tipo, severidade, chave, mensagem) VALUES (', @g, ', ''nivel_baixo'', ''critico'', ''nivel_baixo:', @cx, ''', ''dup'')'), 'Duplicate');

INSERT INTO leitura_sensor (fk_id_sensor, valor) VALUES (@s_niv, 1.2);   -- reabastece: 2400 L
CALL sp_alertas_sincronizar(@g);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'reabastecer a caixa fecha o alerta nivel_baixo',
       IF(COUNT(*) = 0, 'PASS', 'FAIL'), 'sem nivel_baixo aberto' FROM alerta WHERE tipo = 'nivel_baixo' AND resolvido_em IS NULL;

-- sensor offline
UPDATE sensor_controle SET ult_leitura_em = NOW() - INTERVAL 3 HOUR WHERE id_sensor_controle = @s_amb;
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'sensor sem leitura ha 3 h => status desatualizado',
       IF(status = 'desatualizado', 'PASS', 'FAIL'), CONCAT(status, ' (', minutos_sem_leitura, ' min)') FROM vw_dash_sensor WHERE id_sensor = @s_amb;
CALL sp_alertas_sincronizar(@g);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'sensor desatualizado gera alerta sensor_offline', IF(COUNT(*) = 1, 'PASS', 'FAIL'), MAX(mensagem)
  FROM alerta WHERE tipo = 'sensor_offline' AND resolvido_em IS NULL;
INSERT INTO leitura_sensor (fk_id_sensor, valor) VALUES (@s_amb, 27.5);
CALL sp_alertas_sincronizar(@g);

-- culturas incompatíveis
INSERT INTO area_planta (fk_id_area, fk_id_planta, qtd_plantada) VALUES (@ar_a, @p_cac, 5);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'cacto + tomate + alface no mesmo canteiro => umidade incompativel (60 > 40)',
       IF(status_umidade = 'incompativel' AND umid_min_ideal = 60 AND umid_max_ideal = 40, 'PASS', 'FAIL'),
       CONCAT('umidade ', umid_min_ideal, '-', umid_max_ideal, ' => ', status_umidade, ' | pH ', ph_min_ideal, '-', ph_max_ideal, ' => ', status_ph)
  FROM vw_dash_area WHERE id_area = @ar_a;
CALL sp_alertas_sincronizar(@g);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'alerta culturas_incompativeis aberto', IF(COUNT(*) = 1, 'PASS', 'FAIL'), MAX(mensagem)
  FROM alerta WHERE tipo = 'culturas_incompativeis' AND resolvido_em IS NULL;
DELETE FROM area_planta WHERE fk_id_area = @ar_a AND fk_id_planta = @p_cac;
CALL sp_alertas_sincronizar(@g);

-- capacidade máxima de espécies
UPDATE area SET max_especies = 2 WHERE id_area = @ar_a;
CALL t_erro('capacidade maxima de especies da area atingida',
  CONCAT('INSERT INTO area_planta (fk_id_area, fk_id_planta, qtd_plantada) VALUES (', @ar_a, ',', @p_cac, ', 5)'), 'Capacidade maxima');
UPDATE area SET max_especies = 10 WHERE id_area = @ar_a;

-- ===== 7. PLANTAS: PERDA (menu do produtor) ===========================================
INSERT INTO registro_perda (fk_id_area, fk_id_planta, fk_id_estagio, quantidade, causa, fk_id_usuario)
VALUES (@ar_a, @p_tom, @e_ver, 5, 'praga', @u);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'perda de 5 tomates verdes: atual 50 -> 45 (plantada continua 50)',
       IF(qtd_atual = 45 AND qtd_plantada = 50, 'PASS', 'FAIL'), CONCAT(qtd_atual, ' / ', qtd_plantada)
  FROM vw_area_planta_detalhe WHERE fk_id_area = @ar_a AND fk_id_planta = @p_tom;
CALL t_erro('perda maior que o existente no estagio e recusada',
  CONCAT('INSERT INTO registro_perda (fk_id_area, fk_id_planta, fk_id_estagio, quantidade, causa, fk_id_usuario) VALUES (', @ar_a, ',', @p_tom, ',', @e_ver, ', 999, ''x'', ', @u, ')'), 'Perda maior');

-- ===== 8. IRRIGAÇÃO AUTOMÁTICA (Sistema) ================================================
SET @antes := (SELECT COUNT(*) FROM hist_irrigacao WHERE tipo_acionamento = 'automatico' AND fk_id_usuario IS NULL);
CALL sp_irrigacao_automatica(@g);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'sp_irrigacao_automatica irriga a area seca, sem usuario (Sistema)',
       IF(COUNT(*) = @antes + 1, 'PASS', 'FAIL'), CONCAT(COUNT(*) - @antes, ' nova(s)')
  FROM hist_irrigacao WHERE tipo_acionamento = 'automatico' AND fk_id_usuario IS NULL;

-- ===== 9. RELATÓRIOS (UC05) ===============================================================
SET @n_rel_antes := (SELECT COUNT(*) FROM relatorio);
CALL sp_gerar_relatorio(@g, @u, 'completo', NULL, NULL);
SET @rel := (SELECT MAX(id_relatorio) FROM relatorio);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'relatorio completo: todas as abas gravadas com data/hora',
       IF(r.gerado_em IS NOT NULL AND r.origem = 'manual' AND r.usuario_nome = 'Usuario Demo'
          AND (SELECT COUNT(*) FROM rel_area WHERE fk_id_relatorio = @rel) = 2
          AND (SELECT COUNT(*) FROM rel_area_planta WHERE fk_id_relatorio = @rel) = 3
          AND (SELECT COUNT(*) FROM rel_sensor WHERE fk_id_relatorio = @rel) = 7
          AND (SELECT COUNT(*) FROM rel_reservatorio WHERE fk_id_relatorio = @rel) = 1
          AND (SELECT COUNT(*) FROM rel_irrigacao WHERE fk_id_relatorio = @rel) = 2
          AND (SELECT COUNT(*) FROM rel_insumo WHERE fk_id_relatorio = @rel) = 3, 'PASS', 'FAIL'),
       CONCAT('relatorio #', r.id_relatorio, ' em ', r.gerado_em)
  FROM relatorio r WHERE r.id_relatorio = @rel;

-- o relatório é uma FOTOGRAFIA: mudar o presente não muda o passado
SET @est_rel := (SELECT estoque FROM rel_insumo WHERE fk_id_relatorio = @rel AND nome_ins = 'Calcario');
INSERT INTO registro_consumo (qtd_aplicada, motivo, fk_id_insumo, fk_id_area, fk_id_usuario) VALUES (3, 'correcao_ph', @i_cal, @ar_a, @u);
UPDATE plantas SET nome_p = 'Tomate Cereja' WHERE id_planta = @p_tom;
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'snapshot imutavel: consumo e renomeacao posteriores nao alteram o relatorio antigo',
       IF((SELECT estoque FROM rel_insumo WHERE fk_id_relatorio = @rel AND nome_ins = 'Calcario') = @est_rel
          AND (SELECT estoque FROM insumo WHERE id_insumo = @i_cal) = @est_rel - 3
          AND (SELECT COUNT(*) FROM rel_area_planta WHERE fk_id_relatorio = @rel AND planta_nome = 'Tomate') = 1, 'PASS', 'FAIL'),
       CONCAT('relatorio: ', @est_rel, ' kg | agora: ', (SELECT estoque FROM insumo WHERE id_insumo = @i_cal), ' kg');
UPDATE plantas SET nome_p = 'Tomate' WHERE id_planta = @p_tom;

-- relatório por aba
CALL sp_gerar_relatorio(@g, @u, 'insumos', NOW() - INTERVAL 5 DAY, NOW());
SET @rel2 := (SELECT MAX(id_relatorio) FROM relatorio);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'relatorio so da aba Insumos: apenas rel_insumo preenchida',
       IF((SELECT COUNT(*) FROM rel_insumo WHERE fk_id_relatorio = @rel2) = 3
          AND (SELECT COUNT(*) FROM rel_sensor WHERE fk_id_relatorio = @rel2) = 0
          AND (SELECT COUNT(*) FROM rel_area WHERE fk_id_relatorio = @rel2) = 0, 'PASS', 'FAIL'),
       (SELECT CONCAT('periodo ', periodo_inicio, ' a ', periodo_fim) FROM relatorio WHERE id_relatorio = @rel2);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'consumo_periodo respeita a janela (5 dias: ignora o consumo de 7 dias atras)',
       IF(consumo_periodo = 3, 'PASS', 'FAIL'), CONCAT('Calcario: ', consumo_periodo, ' kg no periodo; total ', consumo_total)
  FROM rel_insumo WHERE fk_id_relatorio = @rel2 AND nome_ins = 'Calcario';

CALL sp_gerar_relatorio(@g, NULL, 'alertas', NULL, NULL);
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'relatorio do Sistema (usuario NULL) => origem agendado, "Sistema (automatico)"',
       IF(r.origem = 'agendado' AND r.fk_id_usuario IS NULL AND l.gerado_por = 'Sistema (automatico)', 'PASS', 'FAIL'),
       CONCAT(r.origem, ' / ', l.gerado_por)
  FROM relatorio r JOIN vw_relatorio_lista l ON l.id_relatorio = r.id_relatorio
 WHERE r.id_relatorio = (SELECT MAX(id_relatorio) FROM relatorio);

CALL t_erro('tipo de relatorio invalido',
  CONCAT('CALL sp_gerar_relatorio(', @g, ', NULL, ''abacaxi'', NULL, NULL)'), 'invalido');
CALL t_erro('periodo com inicio depois do fim',
  CONCAT('CALL sp_gerar_relatorio(', @g, ', NULL, ''completo'', NOW(), NOW() - INTERVAL 1 DAY)'), 'Periodo invalido');
CALL t_erro('estufa inexistente',
  'CALL sp_gerar_relatorio(999, NULL, ''completo'', NULL, NULL)', 'Estufa nao encontrada');
INSERT INTO t_res (teste, resultado, detalhe)
SELECT 'relatorios com erro nao deixam lixo (rollback): so os 3 validos foram criados',
       IF((SELECT COUNT(*) FROM relatorio) = @n_rel_antes + 3, 'PASS', 'FAIL'), (SELECT COUNT(*) FROM relatorio) - @n_rel_antes;

-- ===== RESULTADO ===========================================================================
SELECT n, resultado, teste, detalhe FROM t_res ORDER BY n;
SELECT SUM(resultado = 'PASS') AS passaram, SUM(resultado = 'FAIL') AS falharam, COUNT(*) AS total FROM t_res;
