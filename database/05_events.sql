-- =============================================================================
--  GIE_DATA  |  EVENTOS AGENDADOS  (opcional)
--
--  Requer o agendador ligado:   SET GLOBAL event_scheduler = ON;
--  (no MySQL 8 já vem ON por padrão; no my.cnf: event_scheduler=ON)
--  O usuário que roda este arquivo precisa do privilégio EVENT.
--
--  Fuso: o Brasil está em -03:00 o ano todo. Para os horários abaixo e os
--  DATETIME gravados saírem no horário de Brasília, configure o servidor
--  (default-time-zone='-03:00') ou conecte com SET time_zone = '-03:00'.
-- =============================================================================
USE GIE_DATA;

DROP EVENT IF EXISTS ev_alertas_5min;
DROP EVENT IF EXISTS ev_relatorio_diario;

-- UC04: varre sensores/estoques a cada 5 minutos, abrindo e fechando alertas
CREATE EVENT ev_alertas_5min
  ON SCHEDULE EVERY 5 MINUTE
  COMMENT 'UC04 - Monitorar alertas do sistema'
  DO CALL sp_alertas_sincronizar_todos();

-- UC05: relatório completo automático todo dia às 23:55 (origem = agendado)
CREATE EVENT ev_relatorio_diario
  ON SCHEDULE EVERY 1 DAY
  STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 23 HOUR + INTERVAL 55 MINUTE)
  COMMENT 'UC05 - Relatorio completo diario do Sistema (automatico)'
  DO CALL sp_gerar_relatorio_agendado();

-- Irrigação automática (sp_irrigacao_automatica) NÃO é agendada de propósito:
-- ela abre a água de verdade. Para ativar, descomente e ajuste a estufa:
-- CREATE EVENT ev_irrigacao_auto ON SCHEDULE EVERY 15 MINUTE
--   DO CALL sp_irrigacao_automatica(1);
