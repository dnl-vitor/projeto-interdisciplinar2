-- =============================================================================
--  GIE_DATA  |  VIEWS DO DASHBOARD  (rodar depois de 01_schema.sql)
--
--  Cada aba do dashboard lê UMA view (estado ao vivo). Os relatórios
--  (03_procedures.sql -> sp_gerar_relatorio) gravam exatamente estas views
--  nas tabelas rel_*, então "o que a aba mostra" e "o que o relatório guarda"
--  nunca divergem.
--
--    Aba do dashboard        View (ao vivo)             Snapshot (histórico)
--    ----------------------  -------------------------  ---------------------
--    Visão geral (KPIs)      vw_dash_resumo             relatorio (cabeçalho)
--    Áreas de cultivo        vw_dash_area               rel_area
--    Plantas                 vw_area_planta_detalhe     rel_area_planta
--    Irrigação               vw_dash_reservatorio       rel_reservatorio
--                            + hist_irrigacao           rel_irrigacao
--    Sensores / Ambiente     vw_dash_sensor             rel_sensor
--    Insumos / Estoque       vw_dash_insumo             rel_insumo
--    Alertas                 vw_dash_alerta             rel_alerta
-- =============================================================================
USE GIE_DATA;

-- -----------------------------------------------------------------------------
-- Plantas cultivadas em cada área, com parâmetros e estágios (aba Plantas)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_area_planta_detalhe AS
SELECT ap.fk_id_area, ap.fk_id_planta, a.fk_id_garden, a.nome AS area_nome,
       p.nome_p AS planta_nome, p.necessidade_agua, p.necessidade_luz,
       p.ph_ideal_min, p.ph_ideal_max, p.nutricao,
       r.litros_irrigacao, r.umid_min, r.umid_max,
       ap.qtd_plantada, ap.data_plantio,
       COALESCE(e.qtd_atual, 0) AS qtd_atual,
       e.estagios
  FROM area_planta ap
  JOIN area a    ON a.id_area = ap.fk_id_area
  JOIN plantas p ON p.id_planta = ap.fk_id_planta
  JOIN ref_necessidade_agua r ON r.nivel = p.necessidade_agua
  LEFT JOIN (
        SELECT ape.fk_id_area, ape.fk_id_planta,
               SUM(ape.quantidade) AS qtd_atual,
               JSON_OBJECTAGG(es.nome, ape.quantidade) AS estagios
          FROM area_planta_estagio ape
          JOIN estagio_planta es ON es.id_estagio = ape.fk_id_estagio
         GROUP BY ape.fk_id_area, ape.fk_id_planta
       ) e ON e.fk_id_area = ap.fk_id_area AND e.fk_id_planta = ap.fk_id_planta;

-- -----------------------------------------------------------------------------
-- Parâmetros ideais de cada área = INTERSEÇÃO das faixas das plantas nela.
--   umidade ideal: [maior dos mínimos , menor dos máximos]
--   pH ideal:      [maior dos mínimos , menor dos máximos]
-- Se mínimo > máximo, as culturas são incompatíveis na mesma área.
-- Área sem plantas usa a faixa padrão do sensor.
-- volume_ideal_l        = regra do Java (soma 1 valor por ESPÉCIE na área)
-- volume_ideal_total_l  = alternativa (litros x nº de plantas) — decisão do time
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_area_parametros AS
SELECT a.id_area, a.fk_id_garden, a.nome, a.area_m2, a.max_especies,
       a.fk_id_sensor_umidade, a.fk_id_sensor_ph_solo,
       COUNT(d.fk_id_planta)                      AS qtd_especies,
       CAST(COALESCE(SUM(d.qtd_atual), 0) AS SIGNED) AS qtd_plantas,
       COALESCE(MAX(d.umid_min),     su.umid_min) AS umid_min_ideal,
       COALESCE(MIN(d.umid_max),     su.umid_max) AS umid_max_ideal,
       COALESCE(MAX(d.ph_ideal_min), sp.phs_min)  AS ph_min_ideal,
       COALESCE(MIN(d.ph_ideal_max), sp.phs_max)  AS ph_max_ideal,
       COALESCE(SUM(d.litros_irrigacao), 0)                   AS volume_ideal_l,
       COALESCE(SUM(d.litros_irrigacao * d.qtd_atual), 0)     AS volume_ideal_total_l
  FROM area a
  JOIN sensor_umidade su ON su.id_sensor_controle = a.fk_id_sensor_umidade
  JOIN sensor_ph_solo sp ON sp.id_sensor_controle = a.fk_id_sensor_ph_solo
  LEFT JOIN vw_area_planta_detalhe d ON d.fk_id_area = a.id_area
 GROUP BY a.id_area, a.fk_id_garden, a.nome, a.area_m2, a.max_especies,
          a.fk_id_sensor_umidade, a.fk_id_sensor_ph_solo,
          su.umid_min, su.umid_max, sp.phs_min, sp.phs_max;

-- -----------------------------------------------------------------------------
-- ABA ÁREAS DE CULTIVO
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_dash_area AS
SELECT t.*, (t.status_umidade = 'seco') AS precisa_irrigar
  FROM (
    SELECT p.id_area, p.fk_id_garden, p.nome AS area_nome, p.area_m2,
           p.qtd_especies, p.qtd_plantas,
           su.ult_leitura AS umidade, su.ult_leitura_em AS umidade_em,
           p.umid_min_ideal, p.umid_max_ideal,
           CASE WHEN su.ult_leitura IS NULL                   THEN 'sem_leitura'
                WHEN p.umid_min_ideal > p.umid_max_ideal      THEN 'incompativel'
                WHEN su.ult_leitura < p.umid_min_ideal        THEN 'seco'
                WHEN su.ult_leitura > p.umid_max_ideal        THEN 'encharcado'
                ELSE 'ok' END AS status_umidade,
           sh.ult_leitura AS ph_solo, sh.ult_leitura_em AS ph_solo_em,
           p.ph_min_ideal, p.ph_max_ideal,
           CASE WHEN sh.ult_leitura IS NULL                   THEN 'sem_leitura'
                WHEN p.ph_min_ideal > p.ph_max_ideal          THEN 'incompativel'
                WHEN sh.ult_leitura < p.ph_min_ideal          THEN 'baixo'
                WHEN sh.ult_leitura > p.ph_max_ideal          THEN 'alto'
                ELSE 'ok' END AS status_ph,
           p.volume_ideal_l, p.volume_ideal_total_l
      FROM vw_area_parametros p
      JOIN sensor_controle su ON su.id_sensor_controle = p.fk_id_sensor_umidade
      JOIN sensor_controle sh ON sh.id_sensor_controle = p.fk_id_sensor_ph_solo
  ) t;

-- -----------------------------------------------------------------------------
-- ABA SENSORES / AMBIENTE  (todos os tipos, num formato único)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_dash_sensor_base AS
SELECT p.fk_id_garden AS id_garden, sc.id_sensor_controle AS id_sensor, sc.tipo, sc.`local`,
       p.id_area, p.nome AS area_nome, CAST(NULL AS SIGNED) AS id_caixa,
       sc.ult_leitura AS valor, '%' AS unidade,
       IF(p.umid_min_ideal <= p.umid_max_ideal, p.umid_min_ideal, NULL) AS faixa_min,
       IF(p.umid_min_ideal <= p.umid_max_ideal, p.umid_max_ideal, NULL) AS faixa_max,
       sc.ult_leitura_em AS lido_em
  FROM vw_area_parametros p
  JOIN sensor_controle sc ON sc.id_sensor_controle = p.fk_id_sensor_umidade
UNION ALL
SELECT p.fk_id_garden, sc.id_sensor_controle, sc.tipo, sc.`local`,
       p.id_area, p.nome, NULL,
       sc.ult_leitura, 'pH',
       IF(p.ph_min_ideal <= p.ph_max_ideal, p.ph_min_ideal, NULL),
       IF(p.ph_min_ideal <= p.ph_max_ideal, p.ph_max_ideal, NULL),
       sc.ult_leitura_em
  FROM vw_area_parametros p
  JOIN sensor_controle sc ON sc.id_sensor_controle = p.fk_id_sensor_ph_solo
UNION ALL
SELECT g.id_garden, sc.id_sensor_controle, sc.tipo, sc.`local`,
       NULL, NULL, NULL,
       sc.ult_leitura, 'pH', sa.ph_min, sa.ph_max, sc.ult_leitura_em
  FROM garden g
  JOIN sensor_ph_agua sa  ON sa.id_sensor_controle = g.fk_id_sensor_ph_agua
  JOIN sensor_controle sc ON sc.id_sensor_controle = g.fk_id_sensor_ph_agua
UNION ALL
SELECT g.id_garden, sc.id_sensor_controle, sc.tipo, sc.`local`,
       NULL, NULL, NULL,
       sc.ult_leitura, '°C', sm.temp_min, sm.temp_max, sc.ult_leitura_em
  FROM garden g
  JOIN sensor_ambiente sm ON sm.id_sensor_controle = g.fk_id_sensor_ambiente
  JOIN sensor_controle sc ON sc.id_sensor_controle = g.fk_id_sensor_ambiente
UNION ALL
SELECT c.fk_id_garden, sc.id_sensor_controle, sc.tipo, sc.`local`,
       NULL, NULL, c.id_caixa,
       sc.ult_leitura, 'm',
       sn.h_max * g.limite_nivel_baixo_pct / 100,        -- abaixo disso = nível baixo
       sn.h_max, sc.ult_leitura_em
  FROM caixa_dagua c
  JOIN garden g           ON g.id_garden = c.fk_id_garden
  JOIN sensor_nivel sn    ON sn.id_sensor_controle = c.fk_id_sensor_nivel
  JOIN sensor_controle sc ON sc.id_sensor_controle = c.fk_id_sensor_nivel;

CREATE OR REPLACE VIEW vw_dash_sensor AS
SELECT b.*,
       TIMESTAMPDIFF(MINUTE, b.lido_em, NOW()) AS minutos_sem_leitura,
       CASE WHEN b.valor IS NULL THEN 'sem_leitura'
            WHEN TIMESTAMPDIFF(MINUTE, b.lido_em, NOW()) > g.minutos_sensor_offline THEN 'desatualizado'
            WHEN b.faixa_min IS NOT NULL AND b.valor < b.faixa_min THEN 'baixo'
            WHEN b.faixa_max IS NOT NULL AND b.valor > b.faixa_max THEN 'alto'
            ELSE 'ok' END AS status
  FROM vw_dash_sensor_base b
  JOIN garden g ON g.id_garden = b.id_garden;

-- -----------------------------------------------------------------------------
-- ABA IRRIGAÇÃO — reservatórios
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_dash_reservatorio AS
SELECT c.id_caixa, c.fk_id_garden AS id_garden, sc.`local` AS sensor_local,
       c.cap_l, c.vol_atual,
       ROUND(c.vol_atual / c.cap_l * 100, 1) AS nivel_pct,
       g.limite_nivel_baixo_pct AS limite_alerta_pct,
       CASE WHEN c.vol_atual / c.cap_l * 100 < g.limite_nivel_baixo_pct
            THEN 'baixo' ELSE 'ok' END AS status,
       ROUND(c.vol_atual / si.vazao_l, 1) AS autonomia_min
  FROM caixa_dagua c
  JOIN garden g              ON g.id_garden = c.fk_id_garden
  JOIN sistema_irrigacao si  ON si.id_sis_irr = g.fk_id_sist_irriga
  JOIN sensor_controle sc    ON sc.id_sensor_controle = c.fk_id_sensor_nivel;

-- -----------------------------------------------------------------------------
-- ABA INSUMOS / ESTOQUE   (mesma regra do Java: lmt_min > 0 e estoque <= lmt_min)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_dash_insumo AS
SELECT i.id_insumo, i.fk_id_garden AS id_garden, i.nome_ins, i.categoria, i.unidade,
       i.estoque, i.lmt_min, i.consumo_total,
       CASE WHEN i.estoque <= 0 THEN 'zerado'
            WHEN COALESCE(i.lmt_min, 0) > 0 AND i.estoque <= i.lmt_min THEN 'baixo'
            ELSE 'ok' END AS status
  FROM insumo i;

-- -----------------------------------------------------------------------------
-- ALERTAS CALCULADOS AGORA  (porte de Garden.verificarAlertas() do Java)
-- `chave` identifica a condição; sp_alertas_sincronizar usa para abrir/fechar.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_alertas_calculados AS
SELECT r.id_garden, CAST(NULL AS SIGNED) AS id_area, 'nivel_baixo' AS tipo,
       IF(r.nivel_pct < r.limite_alerta_pct / 2, 'critico', 'atencao') AS severidade,
       CONCAT('nivel_baixo:', r.id_caixa) AS chave,
       CONCAT('Caixa d''agua (', r.sensor_local, ') com nivel baixo: ', r.nivel_pct, '%') AS mensagem
  FROM vw_dash_reservatorio r WHERE r.status = 'baixo'
UNION ALL
SELECT a.fk_id_garden, a.id_area, 'irrigar', 'atencao',
       CONCAT('irrigar:', a.id_area),
       CONCAT('Area ', a.area_nome, ' precisa irrigar (umidade ', a.umidade, '% < minimo ', a.umid_min_ideal, '%)')
  FROM vw_dash_area a WHERE a.status_umidade = 'seco'
UNION ALL
SELECT a.fk_id_garden, a.id_area, 'encharcado', 'atencao',
       CONCAT('encharcado:', a.id_area),
       CONCAT('Area ', a.area_nome, ' encharcada (umidade ', a.umidade, '% > maximo ', a.umid_max_ideal, '%)')
  FROM vw_dash_area a WHERE a.status_umidade = 'encharcado'
UNION ALL
SELECT a.fk_id_garden, a.id_area, 'ph_fora', 'atencao',
       CONCAT('ph_fora:', a.id_area),
       CONCAT('Area ', a.area_nome, ' com pH inadequado: ', a.ph_solo, ' (ideal ', a.ph_min_ideal, ' a ', a.ph_max_ideal, ')')
  FROM vw_dash_area a WHERE a.status_ph IN ('baixo','alto')
UNION ALL
SELECT a.fk_id_garden, a.id_area, 'culturas_incompativeis', 'atencao',
       CONCAT('culturas_incompativeis:', a.id_area),
       CONCAT('Area ', a.area_nome, ': as culturas plantadas tem faixas de umidade/pH incompativeis entre si')
  FROM vw_dash_area a WHERE a.status_umidade = 'incompativel' OR a.status_ph = 'incompativel'
UNION ALL
SELECT s.id_garden, NULL, 'ph_agua_fora', 'atencao',
       CONCAT('ph_agua_fora:', s.id_sensor),
       CONCAT('pH da agua (', s.`local`, ') fora da faixa ideal: ', s.valor)
  FROM vw_dash_sensor s WHERE s.tipo = 'ph_agua' AND s.status IN ('baixo','alto')
UNION ALL
SELECT s.id_garden, NULL, 'temperatura_fora', 'atencao',
       CONCAT('temperatura_fora:', s.id_sensor),
       CONCAT('Temperatura (', s.`local`, ') fora da faixa ideal: ', s.valor, ' C')
  FROM vw_dash_sensor s WHERE s.tipo = 'ambiente' AND s.status IN ('baixo','alto')
UNION ALL
SELECT i.id_garden, NULL, 'estoque_baixo', IF(i.status = 'zerado', 'critico', 'atencao'),
       CONCAT('estoque_baixo:', i.id_insumo),
       CONCAT('ALERTA: Estoque de ', i.nome_ins, ' esta ', IF(i.status = 'zerado', 'zerado', 'baixo'),
              ' (', i.estoque, ' ', i.unidade, ')')
  FROM vw_dash_insumo i WHERE i.status IN ('baixo','zerado')
UNION ALL
SELECT s.id_garden, s.id_area, 'sensor_offline',
       IF(s.status = 'sem_leitura', 'info', 'atencao'),
       CONCAT('sensor_offline:', s.id_sensor),
       IF(s.status = 'sem_leitura',
          CONCAT('Sensor (', s.`local`, ') ainda nao enviou nenhuma leitura'),
          CONCAT('Sensor (', s.`local`, ') sem leitura ha ', s.minutos_sem_leitura, ' min'))
  FROM vw_dash_sensor s WHERE s.status IN ('desatualizado','sem_leitura');

-- -----------------------------------------------------------------------------
-- ABA ALERTAS (ao vivo; "aberto_desde" vem da linha do tempo `alerta`, se já registrada)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_dash_alerta AS
SELECT c.id_garden, c.id_area, c.tipo, c.severidade, c.mensagem, c.chave,
       al.id_alerta, al.criado_em AS aberto_desde
  FROM vw_alertas_calculados c
  LEFT JOIN alerta al ON al.fk_id_garden = c.id_garden AND al.chave_aberta = c.chave;

-- -----------------------------------------------------------------------------
-- VISÃO GERAL (faixa de KPIs do topo do dashboard)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_dash_resumo AS
SELECT g.id_garden, g.nome,
       (SELECT COUNT(*) FROM area a WHERE a.fk_id_garden = g.id_garden)                 AS qtd_areas,
       (SELECT COALESCE(SUM(p.qtd_plantas), 0) FROM vw_area_parametros p
         WHERE p.fk_id_garden = g.id_garden)                                           AS qtd_plantas,
       (SELECT COUNT(*) FROM vw_alertas_calculados c WHERE c.id_garden = g.id_garden)   AS alertas_abertos,
       (SELECT COUNT(*) FROM vw_alertas_calculados c
         WHERE c.id_garden = g.id_garden AND c.severidade = 'critico')                  AS alertas_criticos,
       (SELECT ROUND(SUM(c.vol_atual) / SUM(c.cap_l) * 100, 1) FROM caixa_dagua c
         WHERE c.fk_id_garden = g.id_garden)                                           AS nivel_agua_pct,
       (SELECT COALESCE(SUM(c.vol_atual), 0) FROM caixa_dagua c
         WHERE c.fk_id_garden = g.id_garden)                                           AS volume_agua_l,
       (SELECT COUNT(*) FROM vw_dash_insumo i
         WHERE i.id_garden = g.id_garden AND i.status <> 'ok')                          AS insumos_em_alerta,
       si.nome AS irrigacao_nome, si.lig_bol AS irrigacao_ligada, si.vazao_l AS irrigacao_vazao_l,
       (SELECT MAX(h.data_hora) FROM hist_irrigacao h JOIN area a ON a.id_area = h.fk_id_area
         WHERE a.fk_id_garden = g.id_garden)                                           AS ultima_irrigacao,
       (SELECT MAX(r.gerado_em) FROM relatorio r WHERE r.fk_id_garden = g.id_garden)    AS ultimo_relatorio
  FROM garden g
  JOIN sistema_irrigacao si ON si.id_sis_irr = g.fk_id_sist_irriga;

-- -----------------------------------------------------------------------------
-- ABA RELATÓRIOS — lista de relatórios já gerados (com contagens por seção)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_relatorio_lista AS
SELECT r.id_relatorio, r.fk_id_garden AS id_garden, r.garden_nome, r.tipo, r.origem,
       COALESCE(r.usuario_nome, IF(r.origem = 'agendado', 'Sistema (automatico)', '(usuario removido)')) AS gerado_por,
       r.gerado_em, r.periodo_inicio, r.periodo_fim,
       (SELECT COUNT(*) FROM rel_area x       WHERE x.fk_id_relatorio = r.id_relatorio) AS n_areas,
       (SELECT COUNT(*) FROM rel_sensor x     WHERE x.fk_id_relatorio = r.id_relatorio) AS n_sensores,
       (SELECT COUNT(*) FROM rel_insumo x     WHERE x.fk_id_relatorio = r.id_relatorio) AS n_insumos,
       (SELECT COUNT(*) FROM rel_alerta x     WHERE x.fk_id_relatorio = r.id_relatorio) AS n_alertas,
       (SELECT COUNT(*) FROM rel_alerta x     WHERE x.fk_id_relatorio = r.id_relatorio
                                                AND x.severidade = 'critico')           AS n_alertas_criticos
  FROM relatorio r;
