-- =============================================================================
--  GIE_DATA  |  USUÁRIO DA APLICAÇÃO (substitui database/user.sql)
--
--  Correções em relação ao arquivo anterior:
--   * o nome do banco usa CRASES (`GIE_DATA`), não aspas simples;
--   * o host é 'localhost' (antes '%' = aceitava conexão de qualquer lugar);
--   * privilégios mínimos: tabelas de HISTÓRICO e RELATÓRIOS só aceitam
--     SELECT/INSERT — o app nunca consegue alterar ou apagar um relatório,
--     um consumo ou uma irrigação já registrados.
--
--  Troque 'TROQUE_ESTA_SENHA' antes de rodar. Não versione a senha real.
-- =============================================================================
CREATE USER IF NOT EXISTS 'gie_app'@'localhost' IDENTIFIED BY 'TROQUE_ESTA_SENHA';

-- cadastros (o app pode criar, editar e remover)
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.usuario              TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.plantas              TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.estagio_planta       TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.area_planta          TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.area_planta_estagio  TO 'gie_app'@'localhost';
-- insumo / caixa / sensor_controle: colunas "calculadas" (estoque, consumo_total, vol_atual,
-- ult_leitura, ult_leitura_em) NÃO são graváveis pelo app — só os triggers mexem nelas.
-- Estoque inicial entra por entrada_insumo; volume da caixa vem da leitura do sensor de nível.
GRANT SELECT, DELETE ON `GIE_DATA`.insumo TO 'gie_app'@'localhost';
GRANT INSERT (fk_id_garden, nome_ins, categoria, unidade, lmt_min)  ON `GIE_DATA`.insumo TO 'gie_app'@'localhost';
GRANT UPDATE (nome_ins, categoria, unidade, lmt_min)                ON `GIE_DATA`.insumo TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.area                 TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.garden               TO 'gie_app'@'localhost';
GRANT SELECT, DELETE ON `GIE_DATA`.caixa_dagua TO 'gie_app'@'localhost';
GRANT INSERT (cap_l, fk_id_garden, fk_id_sensor_nivel) ON `GIE_DATA`.caixa_dagua TO 'gie_app'@'localhost';
GRANT UPDATE (cap_l)                                   ON `GIE_DATA`.caixa_dagua TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.sistema_irrigacao    TO 'gie_app'@'localhost';
GRANT SELECT, DELETE ON `GIE_DATA`.sensor_controle TO 'gie_app'@'localhost';
GRANT INSERT (`local`, tipo) ON `GIE_DATA`.sensor_controle TO 'gie_app'@'localhost';
GRANT UPDATE (`local`)       ON `GIE_DATA`.sensor_controle TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.sensor_umidade       TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.sensor_ph_solo       TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.sensor_ph_agua       TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.sensor_nivel         TO 'gie_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `GIE_DATA`.sensor_ambiente      TO 'gie_app'@'localhost';
GRANT SELECT, UPDATE                 ON `GIE_DATA`.ref_necessidade_agua TO 'gie_app'@'localhost';

-- históricos: só ler e acrescentar (os triggers/procedures atualizam estoque,
-- volume e alertas com o privilégio de quem as criou — DEFINER)
GRANT SELECT, INSERT ON `GIE_DATA`.leitura_sensor   TO 'gie_app'@'localhost';
GRANT SELECT, INSERT ON `GIE_DATA`.registro_consumo TO 'gie_app'@'localhost';
GRANT SELECT, INSERT ON `GIE_DATA`.entrada_insumo   TO 'gie_app'@'localhost';
GRANT SELECT, INSERT ON `GIE_DATA`.registro_perda   TO 'gie_app'@'localhost';
GRANT SELECT, INSERT ON `GIE_DATA`.hist_irrigacao   TO 'gie_app'@'localhost';
GRANT SELECT         ON `GIE_DATA`.alerta           TO 'gie_app'@'localhost';

-- relatórios: SOMENTE leitura (quem grava é sp_gerar_relatorio)
GRANT SELECT ON `GIE_DATA`.relatorio        TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.rel_sensor       TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.rel_reservatorio TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.rel_area         TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.rel_area_planta  TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.rel_irrigacao    TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.rel_insumo       TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.rel_alerta       TO 'gie_app'@'localhost';

-- views do dashboard
GRANT SELECT ON `GIE_DATA`.vw_dash_resumo         TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.vw_dash_area           TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.vw_dash_sensor         TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.vw_dash_reservatorio   TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.vw_dash_insumo         TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.vw_dash_alerta         TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.vw_area_planta_detalhe TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.vw_area_parametros     TO 'gie_app'@'localhost';
GRANT SELECT ON `GIE_DATA`.vw_relatorio_lista     TO 'gie_app'@'localhost';

-- operações compostas
GRANT EXECUTE ON PROCEDURE `GIE_DATA`.sp_irrigar_area         TO 'gie_app'@'localhost';
GRANT EXECUTE ON PROCEDURE `GIE_DATA`.sp_irrigacao_automatica TO 'gie_app'@'localhost';
GRANT EXECUTE ON PROCEDURE `GIE_DATA`.sp_verificar_alertas    TO 'gie_app'@'localhost';
GRANT EXECUTE ON PROCEDURE `GIE_DATA`.sp_gerar_relatorio      TO 'gie_app'@'localhost';

FLUSH PRIVILEGES;
