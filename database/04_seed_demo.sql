-- =============================================================================
--  GIE_DATA  |  DADOS DE DEMONSTRAÇÃO  (opcional — rode UMA vez, em banco vazio)
--
--  Reproduz o DadosSistema.java do PDF (Estufa Sustentável, Canteiro A,
--  Tomate, Alface, caixa de 5000 L, NPK/Calcário/Enxofre, irrigação 8 L/min)
--  e acrescenta um Canteiro B (Cacto) + 24 h de leituras para os gráficos.
--
--  Estado final proposital (como no Java): Canteiro A com umidade 25% (seco),
--  pH 6,8, caixa com 48% — o dashboard abre com um alerta "irrigar" real.
-- =============================================================================
USE GIE_DATA;

-- Usuário de demonstração (a senha NÃO é um hash válido: não dá para logar com ele;
-- serve só para assinar os registros de exemplo). Contas reais: pelo cadastro.php.
INSERT INTO usuario (nome_comp, email, senha, status)
SELECT 'Usuario Demo', 'demo@gie.local', '!sem-login', 'ativo'
 WHERE NOT EXISTS (SELECT 1 FROM usuario WHERE email = 'demo@gie.local');
SET @u := (SELECT id_usuario FROM usuario WHERE email = 'demo@gie.local');

-- ---- sensores -----------------------------------------------------------------
INSERT INTO sensor_controle (`local`, tipo) VALUES ('Interior', 'ambiente');
SET @s_amb := LAST_INSERT_ID();
INSERT INTO sensor_ambiente (id_sensor_controle, temp_min, temp_max) VALUES (@s_amb, 15, 35);

INSERT INTO sensor_controle (`local`, tipo) VALUES ('Agua da chuva', 'ph_agua');
SET @s_pha := LAST_INSERT_ID();
INSERT INTO sensor_ph_agua (id_sensor_controle, ph_min, ph_max) VALUES (@s_pha, 6, 8);

INSERT INTO sensor_controle (`local`, tipo) VALUES ('Tanque Sul', 'nivel');
SET @s_niv := LAST_INSERT_ID();
INSERT INTO sensor_nivel (id_sensor_controle, h_max) VALUES (@s_niv, 2.5);

INSERT INTO sensor_controle (`local`, tipo) VALUES ('Canteiro A', 'umidade');
SET @s_ua := LAST_INSERT_ID();
INSERT INTO sensor_umidade (id_sensor_controle, umid_min, umid_max) VALUES (@s_ua, 30, 70);
INSERT INTO sensor_controle (`local`, tipo) VALUES ('Canteiro A', 'ph_solo');
SET @s_pa := LAST_INSERT_ID();
INSERT INTO sensor_ph_solo (id_sensor_controle, phs_min, phs_max) VALUES (@s_pa, 6, 7);

INSERT INTO sensor_controle (`local`, tipo) VALUES ('Canteiro B', 'umidade');
SET @s_ub := LAST_INSERT_ID();
INSERT INTO sensor_umidade (id_sensor_controle, umid_min, umid_max) VALUES (@s_ub, 0, 40);
INSERT INTO sensor_controle (`local`, tipo) VALUES ('Canteiro B', 'ph_solo');
SET @s_pb := LAST_INSERT_ID();
INSERT INTO sensor_ph_solo (id_sensor_controle, phs_min, phs_max) VALUES (@s_pb, 7, 8);

-- ---- estufa, irrigação, caixa, áreas -------------------------------------------
INSERT INTO sistema_irrigacao (nome, lig_bol, vazao_l) VALUES ('Gotejamento', 1, 8);
SET @sis := LAST_INSERT_ID();

INSERT INTO garden (nome, fk_id_sensor_ambiente, fk_id_sensor_ph_agua, fk_id_sist_irriga)
VALUES ('Estufa Sustentavel', @s_amb, @s_pha, @sis);
SET @g := LAST_INSERT_ID();

INSERT INTO caixa_dagua (cap_l, fk_id_garden, fk_id_sensor_nivel) VALUES (5000, @g, @s_niv);
SET @cx := LAST_INSERT_ID();

INSERT INTO area (nome, area_m2, fk_id_garden, fk_id_sensor_umidade, fk_id_sensor_ph_solo)
VALUES ('Canteiro A', 15, @g, @s_ua, @s_pa);
SET @ar_a := LAST_INSERT_ID();
INSERT INTO area (nome, area_m2, fk_id_garden, fk_id_sensor_umidade, fk_id_sensor_ph_solo)
VALUES ('Canteiro B', 8, @g, @s_ub, @s_pb);
SET @ar_b := LAST_INSERT_ID();

-- ---- plantas (catálogo) e cultivo por área ---------------------------------------
INSERT INTO plantas (nome_p, necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao) VALUES
  ('Tomate', 'media', 'sol_pleno',   6.0, 7.0, 'alta'),
  ('Alface', 'alta',  'meia_sombra', 6.0, 7.5, 'media'),
  ('Cacto',  'baixa', 'sol_pleno',   7.0, 8.0, 'baixa');
SET @p_tom := (SELECT id_planta FROM plantas WHERE nome_p = 'Tomate');
SET @p_alf := (SELECT id_planta FROM plantas WHERE nome_p = 'Alface');
SET @p_cac := (SELECT id_planta FROM plantas WHERE nome_p = 'Cacto');
SET @e_bro := (SELECT id_estagio FROM estagio_planta WHERE nome = 'broto');
SET @e_ver := (SELECT id_estagio FROM estagio_planta WHERE nome = 'verde');
SET @e_mad := (SELECT id_estagio FROM estagio_planta WHERE nome = 'maduro');

INSERT INTO area_planta (fk_id_area, fk_id_planta, qtd_plantada, data_plantio) VALUES
  (@ar_a, @p_tom, 50, CURRENT_DATE - INTERVAL 60 DAY),
  (@ar_a, @p_alf, 50, CURRENT_DATE - INTERVAL 40 DAY),
  (@ar_b, @p_cac, 12, CURRENT_DATE - INTERVAL 90 DAY);

INSERT INTO area_planta_estagio (fk_id_area, fk_id_planta, fk_id_estagio, quantidade) VALUES
  (@ar_a, @p_tom, @e_ver, 20), (@ar_a, @p_tom, @e_mad, 10), (@ar_a, @p_tom, @e_bro, 20),
  (@ar_a, @p_alf, @e_mad, 30), (@ar_a, @p_alf, @e_bro, 20),
  (@ar_b, @p_cac, @e_mad, 12);

-- ---- insumos: estoque inicial via entrada (30 dias atrás) -------------------------
INSERT INTO insumo (fk_id_garden, nome_ins, categoria, unidade, lmt_min) VALUES
  (@g, 'Fertilizante NPK', 'fertilizante', 'kg', 10),
  (@g, 'Calcario',         'corretivo_ph', 'kg',  5),
  (@g, 'Enxofre',          'corretivo_ph', 'kg',  2);
SET @i_npk := (SELECT id_insumo FROM insumo WHERE nome_ins = 'Fertilizante NPK');
SET @i_cal := (SELECT id_insumo FROM insumo WHERE nome_ins = 'Calcario');
SET @i_enx := (SELECT id_insumo FROM insumo WHERE nome_ins = 'Enxofre');

INSERT INTO entrada_insumo (fk_id_insumo, quantidade, data_hora, fk_id_usuario, observacao) VALUES
  (@i_npk, 50, NOW() - INTERVAL 30 DAY, @u, 'estoque inicial'),
  (@i_cal, 20, NOW() - INTERVAL 30 DAY, @u, 'estoque inicial'),
  (@i_enx, 10, NOW() - INTERVAL 30 DAY, @u, 'estoque inicial');

INSERT INTO registro_consumo (qtd_aplicada, data_hora, motivo, observacao, fk_id_insumo, fk_id_area, fk_id_usuario) VALUES
  (5.0, NOW() - INTERVAL 12 DAY, 'adubacao',    'adubacao de cobertura', @i_npk, @ar_a, @u),
  (2.0, NOW() - INTERVAL  7 DAY, 'correcao_ph', 'pH abaixo do ideal',    @i_cal, @ar_a, @u),
  (1.5, NOW() - INTERVAL  3 DAY, 'correcao_ph', 'pH acima do ideal',     @i_enx, @ar_b, @u);

-- ---- histórico de irrigações (inseridos direto: são só exemplos de histórico) ------
INSERT INTO hist_irrigacao (fk_id_area, fk_id_caixa, fk_id_usuario, tempo_efetivo_min, agua_usada_l, tipo_acionamento, data_hora) VALUES
  (@ar_a, @cx, NULL, 0.63, 5.0, 'automatico', NOW() - INTERVAL 6 DAY),
  (@ar_a, @cx, @u,   0.63, 5.0, 'manual',     NOW() - INTERVAL 4 DAY),
  (@ar_a, @cx, @u,   2.00, 16.0,'forcado',    NOW() - INTERVAL 2 DAY),
  (@ar_b, @cx, NULL, 0.06, 0.5, 'automatico', NOW() - INTERVAL 1 DAY);

-- ---- 24 h de leituras (a cada 30 min) para os gráficos ---------------------------
-- Valores determinísticos (senoides), terminando perto do estado final desejado.
INSERT INTO leitura_sensor (fk_id_sensor, valor, data_hora, origem)
WITH RECURSIVE n (i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < 47),
     sens (k, id) AS (
        SELECT 'amb', @s_amb UNION ALL SELECT 'pha', @s_pha UNION ALL SELECT 'niv', @s_niv
        UNION ALL SELECT 'ua', @s_ua UNION ALL SELECT 'pa', @s_pa
        UNION ALL SELECT 'ub', @s_ub UNION ALL SELECT 'pb', @s_pb)
SELECT sens.id,
       ROUND(CASE sens.k
               WHEN 'amb' THEN 25 + 4 * SIN((n.i - 12) / 48 * 2 * PI())
               WHEN 'pha' THEN 6.8 + 0.15 * SIN(n.i / 5)
               WHEN 'niv' THEN 1.35 - n.i * 0.003 + 0.02 * SIN(n.i)
               WHEN 'ua'  THEN 62 - n.i * 0.78 + 1.5 * SIN(n.i * 1.7)
               WHEN 'pa'  THEN 6.6 + 0.2 * SIN(n.i / 7)
               WHEN 'ub'  THEN 30 + 4 * SIN(n.i / 6)
               WHEN 'pb'  THEN 7.4 + 0.15 * SIN(n.i / 9)
             END, 2),
       NOW() - INTERVAL ((48 - n.i) * 30) MINUTE,
       'sensor'
  FROM n CROSS JOIN sens
 ORDER BY n.i, sens.id;

-- leituras ATUAIS (estado final do demo, igual ao Java)
INSERT INTO leitura_sensor (fk_id_sensor, valor, origem) VALUES
  (@s_amb, 27.5, 'sensor'),   -- temperatura 27,5 °C
  (@s_pha, 6.8,  'sensor'),   -- pH da água 6,8
  (@s_niv, 1.2,  'sensor'),   -- 1,2 m de 2,5 m = 48% -> 2400 L
  (@s_ua,  25.0, 'sensor'),   -- Canteiro A seco (25% < 60%)
  (@s_pa,  6.8,  'sensor'),   -- pH 6,8 (dentro de 6,0-7,0: no Java aparecia "fora" por bug)
  (@s_ub,  35.0, 'sensor'),
  (@s_pb,  7.4,  'sensor');

-- ---- primeira rodada de alertas e um relatório de exemplo --------------------------
CALL sp_alertas_sincronizar(@g);
CALL sp_gerar_relatorio(@g, @u, 'completo', NULL, NULL);
