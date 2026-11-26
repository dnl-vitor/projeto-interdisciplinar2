-- =============================================================================
--  GIE_DATA  |  SCHEMA v2  |  MySQL 8.0+
--  Gestão Inteligente de Estufas — dashboard único (sem cargos/perfis)
--
--  Ordem de execução:  01_schema.sql -> 02_views.sql -> 03_procedures.sql
--                      -> 04_seed_demo.sql (opcional) -> 05_events.sql (opcional)
--
--  ATENÇÃO: este script RECRIA todas as tabelas, EXCETO `usuario`
--           (preservada para não perder as contas já cadastradas).
--           Se `usuario` já existir na estrutura antiga, rode depois
--           o bloco "MIGRAÇÃO DE usuario" no final deste arquivo.
-- =============================================================================

DROP DATABASE IF EXISTS GIE_DATA;
CREATE DATABASE GIE_DATA CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE GIE_DATA;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS
  rel_alerta, rel_irrigacao, rel_insumo, rel_area_planta, rel_area,
  rel_reservatorio, rel_sensor, relatorio,
  alerta, leitura_sensor, hist_irrigacao,
  registro_consumo, entrada_insumo, insumo,
  registro_perda, area_planta_estagio, area_planta, estagio_planta,
  plantas, ref_necessidade_agua,
  area, caixa_dagua, garden, sistema_irrigacao,
  sensor_ambiente, sensor_nivel, sensor_ph_agua, sensor_ph_solo,
  sensor_umidade, sensor_controle,
  perfil;                               -- removida: o sistema não tem cargos

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- 1. USUÁRIO (apenas autenticação e auditoria — sem perfil/cargo)
-- =============================================================================
CREATE TABLE IF NOT EXISTS usuario (
  id_usuario  INT          NOT NULL AUTO_INCREMENT,
  nome_comp   VARCHAR(100) NOT NULL DEFAULT '',
  email       VARCHAR(50)  NOT NULL,                 -- é o "login" do modelo lógico
  senha       VARCHAR(200) NOT NULL,                 -- password_hash() do PHP
  status      ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  criado_em   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_usuario),
  UNIQUE KEY uk_usuario_login (email)
) ENGINE=InnoDB;

-- =============================================================================
-- 2. SENSORES  (supertipo `sensor_controle` + 5 subtipos)
--    Cada subtipo carrega uma coluna `tipo` GERADA e uma FK composta
--    (id, tipo): o banco impede, p.ex., ligar uma linha de `sensor_umidade`
--    a um sensor cujo tipo é 'nivel'.
-- =============================================================================
CREATE TABLE sensor_controle (
  id_sensor_controle INT NOT NULL AUTO_INCREMENT,
  `local`            VARCHAR(100) NOT NULL,
  tipo               ENUM('umidade','ph_solo','ph_agua','nivel','ambiente') NOT NULL,
  ult_leitura        DOUBLE   NULL COMMENT 'cache da última linha de leitura_sensor',
  ult_leitura_em     DATETIME NULL COMMENT 'quando a última leitura foi feita',
  PRIMARY KEY (id_sensor_controle),
  UNIQUE KEY uk_sensor_id_tipo (id_sensor_controle, tipo),
  KEY idx_sensor_controle_tipo (tipo)
) ENGINE=InnoDB;

CREATE TABLE sensor_umidade (
  id_sensor_controle INT NOT NULL,
  tipo ENUM('umidade','ph_solo','ph_agua','nivel','ambiente') GENERATED ALWAYS AS ('umidade') STORED,
  umid_min DOUBLE NOT NULL COMMENT '% — faixa padrão, usada só quando a área não tem plantas',
  umid_max DOUBLE NOT NULL,
  PRIMARY KEY (id_sensor_controle),
  CONSTRAINT fk_umidade_sensor FOREIGN KEY (id_sensor_controle, tipo)
    REFERENCES sensor_controle (id_sensor_controle, tipo) ON DELETE CASCADE,
  CONSTRAINT ck_umidade_faixa CHECK (umid_min >= 0 AND umid_max <= 100 AND umid_min < umid_max)
) ENGINE=InnoDB;

CREATE TABLE sensor_ph_solo (
  id_sensor_controle INT NOT NULL,
  tipo ENUM('umidade','ph_solo','ph_agua','nivel','ambiente') GENERATED ALWAYS AS ('ph_solo') STORED,
  phs_min DOUBLE NOT NULL COMMENT 'faixa padrão, usada só quando a área não tem plantas',
  phs_max DOUBLE NOT NULL,
  PRIMARY KEY (id_sensor_controle),
  CONSTRAINT fk_ph_solo_sensor FOREIGN KEY (id_sensor_controle, tipo)
    REFERENCES sensor_controle (id_sensor_controle, tipo) ON DELETE CASCADE,
  CONSTRAINT ck_ph_solo_faixa CHECK (phs_min >= 0 AND phs_max <= 14 AND phs_min < phs_max)
) ENGINE=InnoDB;

CREATE TABLE sensor_ph_agua (
  id_sensor_controle INT NOT NULL,
  tipo ENUM('umidade','ph_solo','ph_agua','nivel','ambiente') GENERATED ALWAYS AS ('ph_agua') STORED,
  ph_min DOUBLE NOT NULL,
  ph_max DOUBLE NOT NULL,
  PRIMARY KEY (id_sensor_controle),
  CONSTRAINT fk_ph_agua_sensor FOREIGN KEY (id_sensor_controle, tipo)
    REFERENCES sensor_controle (id_sensor_controle, tipo) ON DELETE CASCADE,
  CONSTRAINT ck_ph_agua_faixa CHECK (ph_min >= 0 AND ph_max <= 14 AND ph_min < ph_max)
) ENGINE=InnoDB;

CREATE TABLE sensor_nivel (
  id_sensor_controle INT NOT NULL,
  tipo ENUM('umidade','ph_solo','ph_agua','nivel','ambiente') GENERATED ALWAYS AS ('nivel') STORED,
  h_max DOUBLE NOT NULL COMMENT 'altura útil da caixa (m): leitura == h_max significa caixa cheia',
  PRIMARY KEY (id_sensor_controle),
  CONSTRAINT fk_nivel_sensor FOREIGN KEY (id_sensor_controle, tipo)
    REFERENCES sensor_controle (id_sensor_controle, tipo) ON DELETE CASCADE,
  CONSTRAINT ck_nivel_hmax CHECK (h_max > 0)
) ENGINE=InnoDB;

CREATE TABLE sensor_ambiente (
  id_sensor_controle INT NOT NULL,
  tipo ENUM('umidade','ph_solo','ph_agua','nivel','ambiente') GENERATED ALWAYS AS ('ambiente') STORED,
  temp_min DOUBLE NULL COMMENT '°C — faixa ideal da estufa (opcional)',
  temp_max DOUBLE NULL,
  PRIMARY KEY (id_sensor_controle),
  CONSTRAINT fk_ambiente_sensor FOREIGN KEY (id_sensor_controle, tipo)
    REFERENCES sensor_controle (id_sensor_controle, tipo) ON DELETE CASCADE,
  CONSTRAINT ck_ambiente_faixa CHECK (temp_min IS NULL OR temp_max IS NULL OR temp_min < temp_max)
) ENGINE=InnoDB;

-- =============================================================================
-- 3. ESTUFA, IRRIGAÇÃO, RESERVATÓRIO, ÁREAS
-- =============================================================================
CREATE TABLE sistema_irrigacao (
  id_sis_irr INT NOT NULL AUTO_INCREMENT,
  nome       VARCHAR(50) NOT NULL,
  lig_bol    TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '1 = ligado',
  vazao_l    DOUBLE      NOT NULL COMMENT 'vazão em litros por minuto',
  PRIMARY KEY (id_sis_irr),
  CONSTRAINT ck_sistirr_vazao CHECK (vazao_l > 0)
) ENGINE=InnoDB;

CREATE TABLE garden (
  id_garden              INT          NOT NULL AUTO_INCREMENT,
  nome                   VARCHAR(100) NOT NULL,
  fk_id_sensor_ambiente  INT          NOT NULL,
  fk_id_sensor_ph_agua   INT          NOT NULL,
  fk_id_sist_irriga      INT          NOT NULL,
  limite_nivel_baixo_pct DOUBLE       NOT NULL DEFAULT 20 COMMENT 'alerta quando a caixa fica abaixo deste %',
  minutos_sensor_offline INT          NOT NULL DEFAULT 30 COMMENT 'sensor sem leitura há mais que isso = desatualizado',
  PRIMARY KEY (id_garden),
  UNIQUE KEY uk_garden_nome (nome),
  UNIQUE KEY uk_garden_sensor_ambiente (fk_id_sensor_ambiente),
  UNIQUE KEY uk_garden_sensor_ph_agua (fk_id_sensor_ph_agua),
  UNIQUE KEY uk_garden_sist_irriga (fk_id_sist_irriga),
  CONSTRAINT fk_garden_sensor_ambiente FOREIGN KEY (fk_id_sensor_ambiente) REFERENCES sensor_ambiente (id_sensor_controle),
  CONSTRAINT fk_garden_sensor_ph_agua  FOREIGN KEY (fk_id_sensor_ph_agua)  REFERENCES sensor_ph_agua (id_sensor_controle),
  CONSTRAINT fk_garden_sist_irriga     FOREIGN KEY (fk_id_sist_irriga)     REFERENCES sistema_irrigacao (id_sis_irr),
  CONSTRAINT ck_garden_limite CHECK (limite_nivel_baixo_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_garden_offline CHECK (minutos_sensor_offline > 0)
) ENGINE=InnoDB;

CREATE TABLE caixa_dagua (
  id_caixa           INT    NOT NULL AUTO_INCREMENT,
  cap_l              DOUBLE NOT NULL,
  vol_atual          DOUBLE NOT NULL DEFAULT 0 COMMENT 'litros — mantido pelo trigger de leitura_sensor',
  fk_id_garden       INT    NOT NULL,
  fk_id_sensor_nivel INT    NOT NULL,
  PRIMARY KEY (id_caixa),
  UNIQUE KEY uk_caixa_sensor_nivel (fk_id_sensor_nivel),
  KEY idx_caixa_garden (fk_id_garden),
  CONSTRAINT fk_caixa_garden       FOREIGN KEY (fk_id_garden)       REFERENCES garden (id_garden),
  CONSTRAINT fk_caixa_sensor_nivel FOREIGN KEY (fk_id_sensor_nivel) REFERENCES sensor_nivel (id_sensor_controle),
  CONSTRAINT ck_caixa_cap CHECK (cap_l > 0),
  CONSTRAINT ck_caixa_vol CHECK (vol_atual >= 0 AND vol_atual <= cap_l)
) ENGINE=InnoDB;

CREATE TABLE area (
  id_area              INT          NOT NULL AUTO_INCREMENT,
  nome                 VARCHAR(50)  NOT NULL COMMENT 'ex.: Canteiro A',
  area_m2              DOUBLE       NOT NULL,
  max_especies         INT          NOT NULL DEFAULT 10 COMMENT 'capacidade máxima de espécies na área',
  fk_id_garden         INT          NOT NULL,
  fk_id_sensor_umidade INT          NOT NULL,
  fk_id_sensor_ph_solo INT          NOT NULL,
  PRIMARY KEY (id_area),
  UNIQUE KEY uk_area_nome (fk_id_garden, nome),
  UNIQUE KEY uk_area_sensor_umidade (fk_id_sensor_umidade),
  UNIQUE KEY uk_area_sensor_ph_solo (fk_id_sensor_ph_solo),
  CONSTRAINT fk_area_garden        FOREIGN KEY (fk_id_garden)         REFERENCES garden (id_garden),
  CONSTRAINT fk_area_sensor_umid   FOREIGN KEY (fk_id_sensor_umidade) REFERENCES sensor_umidade (id_sensor_controle),
  CONSTRAINT fk_area_sensor_ph     FOREIGN KEY (fk_id_sensor_ph_solo) REFERENCES sensor_ph_solo (id_sensor_controle),
  CONSTRAINT ck_area_m2 CHECK (area_m2 > 0),
  CONSTRAINT ck_area_max CHECK (max_especies > 0)
) ENGINE=InnoDB;

-- =============================================================================
-- 4. PLANTAS (catálogo), ESTÁGIOS E CULTIVO POR ÁREA
-- =============================================================================
-- Tabela de referência: transforma as constantes que estavam "hardcoded" no
-- Java (3.0 / 2.0 / 0.5 L e as faixas de umidade) em parâmetros editáveis.
CREATE TABLE ref_necessidade_agua (
  nivel            VARCHAR(20) NOT NULL,
  litros_irrigacao DOUBLE      NOT NULL COMMENT 'litros por irrigação, por espécie na área (regra do Java)',
  umid_min         DOUBLE      NOT NULL COMMENT '% de umidade do solo mínima adequada',
  umid_max         DOUBLE      NOT NULL COMMENT '% de umidade do solo máxima adequada',
  PRIMARY KEY (nivel),
  CONSTRAINT ck_refagua CHECK (litros_irrigacao > 0 AND umid_min >= 0 AND umid_max <= 100 AND umid_min < umid_max)
) ENGINE=InnoDB;

INSERT INTO ref_necessidade_agua (nivel, litros_irrigacao, umid_min, umid_max) VALUES
  ('alta',  3.0, 60, 100),
  ('media', 2.0, 30,  70),
  ('baixa', 0.5,  0,  40);

CREATE TABLE plantas (
  id_planta        INT          NOT NULL AUTO_INCREMENT,
  nome_p           VARCHAR(100) NOT NULL,
  necessidade_agua VARCHAR(20)  NOT NULL,
  necessidade_luz  ENUM('sol_pleno','meia_sombra') NOT NULL,
  ph_ideal_min     DOUBLE       NOT NULL,
  ph_ideal_max     DOUBLE       NOT NULL,
  nutricao         ENUM('baixa','media','alta') NOT NULL,
  PRIMARY KEY (id_planta),
  UNIQUE KEY uk_plantas_nome (nome_p),
  CONSTRAINT fk_plantas_necagua FOREIGN KEY (necessidade_agua) REFERENCES ref_necessidade_agua (nivel),
  CONSTRAINT ck_plantas_ph CHECK (ph_ideal_min >= 0 AND ph_ideal_max <= 14 AND ph_ideal_min < ph_ideal_max)
) ENGINE=InnoDB;

-- Estágios de maturação (verdes, maduros, brotos...) — antes era texto livre no Java
CREATE TABLE estagio_planta (
  id_estagio SMALLINT    NOT NULL AUTO_INCREMENT,
  nome       VARCHAR(30) NOT NULL,
  ordem      TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id_estagio),
  UNIQUE KEY uk_estagio_nome (nome)
) ENGINE=InnoDB;

INSERT INTO estagio_planta (nome, ordem) VALUES ('broto',1), ('verde',2), ('maduro',3);

CREATE TABLE area_planta (
  fk_id_area   INT  NOT NULL,
  fk_id_planta INT  NOT NULL,
  qtd_plantada INT  NOT NULL COMMENT 'quantidade INICIAL plantada (a atual = soma dos estágios)',
  data_plantio DATE NOT NULL DEFAULT (CURRENT_DATE),
  PRIMARY KEY (fk_id_area, fk_id_planta),
  KEY idx_areaplanta_planta (fk_id_planta),
  CONSTRAINT fk_areaplanta_area   FOREIGN KEY (fk_id_area)   REFERENCES area (id_area) ON DELETE CASCADE,
  CONSTRAINT fk_areaplanta_planta FOREIGN KEY (fk_id_planta) REFERENCES plantas (id_planta),
  CONSTRAINT ck_areaplanta_qtd CHECK (qtd_plantada > 0)
) ENGINE=InnoDB;

CREATE TABLE area_planta_estagio (
  fk_id_area    INT      NOT NULL,
  fk_id_planta  INT      NOT NULL,
  fk_id_estagio SMALLINT NOT NULL,
  quantidade    INT      NOT NULL DEFAULT 0,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (fk_id_area, fk_id_planta, fk_id_estagio),
  CONSTRAINT fk_apest_areaplanta FOREIGN KEY (fk_id_area, fk_id_planta)
    REFERENCES area_planta (fk_id_area, fk_id_planta) ON DELETE CASCADE,
  CONSTRAINT fk_apest_estagio FOREIGN KEY (fk_id_estagio) REFERENCES estagio_planta (id_estagio),
  CONSTRAINT ck_apest_qtd CHECK (quantidade >= 0)
) ENGINE=InnoDB;

-- "Notificar e Registrar Perda de Planta" (menu do produtor no GIE.jar)
CREATE TABLE registro_perda (
  id_perda      BIGINT       NOT NULL AUTO_INCREMENT,
  fk_id_area    INT          NOT NULL,
  fk_id_planta  INT          NOT NULL,
  fk_id_estagio SMALLINT     NOT NULL,
  quantidade    INT          NOT NULL,
  causa         VARCHAR(100) NOT NULL COMMENT 'ex.: praga, necrose',
  data_hora     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fk_id_usuario INT          NOT NULL,
  PRIMARY KEY (id_perda),
  KEY idx_perda_data (data_hora),
  CONSTRAINT fk_perda_estagio  FOREIGN KEY (fk_id_area, fk_id_planta, fk_id_estagio)
    REFERENCES area_planta_estagio (fk_id_area, fk_id_planta, fk_id_estagio),
  CONSTRAINT fk_perda_usuario  FOREIGN KEY (fk_id_usuario) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_perda_qtd CHECK (quantidade > 0)
) ENGINE=InnoDB;

-- =============================================================================
-- 5. INSUMOS
-- =============================================================================
CREATE TABLE insumo (
  id_insumo     INT          NOT NULL AUTO_INCREMENT,
  fk_id_garden  INT          NOT NULL,
  nome_ins      VARCHAR(100) NOT NULL,
  categoria     ENUM('corretivo_ph','fertilizante','outro') NOT NULL DEFAULT 'outro',
  unidade       VARCHAR(10)  NOT NULL DEFAULT 'kg',
  estoque       DOUBLE       NOT NULL DEFAULT 0 COMMENT 'mantido por triggers (entrada/consumo)',
  lmt_min       DOUBLE       NULL     COMMENT 'alerta quando estoque <= lmt_min (NULL/0 = sem alerta)',
  consumo_total DOUBLE       NOT NULL DEFAULT 0 COMMENT 'acumulado — mantido por trigger',
  PRIMARY KEY (id_insumo),
  UNIQUE KEY uk_insumo_nome (fk_id_garden, nome_ins),
  CONSTRAINT fk_insumo_garden FOREIGN KEY (fk_id_garden) REFERENCES garden (id_garden),
  CONSTRAINT ck_insumo_estoque CHECK (estoque >= 0),
  CONSTRAINT ck_insumo_lmt CHECK (lmt_min IS NULL OR lmt_min >= 0)
) ENGINE=InnoDB;

-- Reposição de estoque (no Java só existia o estoque inicial)
CREATE TABLE entrada_insumo (
  id_entrada    BIGINT       NOT NULL AUTO_INCREMENT,
  fk_id_insumo  INT          NOT NULL,
  quantidade    DOUBLE       NOT NULL,
  data_hora     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fk_id_usuario INT          NOT NULL,
  observacao    VARCHAR(200) NULL,
  PRIMARY KEY (id_entrada),
  KEY idx_entrada_insumo (fk_id_insumo, data_hora),
  CONSTRAINT fk_entrada_insumo  FOREIGN KEY (fk_id_insumo)  REFERENCES insumo (id_insumo),
  CONSTRAINT fk_entrada_usuario FOREIGN KEY (fk_id_usuario) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_entrada_qtd CHECK (quantidade > 0)
) ENGINE=InnoDB;

CREATE TABLE registro_consumo (
  id_registro   BIGINT       NOT NULL AUTO_INCREMENT,
  qtd_aplicada  DOUBLE       NOT NULL,
  data_hora     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  motivo        ENUM('correcao_ph','adubacao','outro') NOT NULL DEFAULT 'outro',
  observacao    VARCHAR(200) NULL,
  fk_id_insumo  INT          NOT NULL,
  fk_id_area    INT          NOT NULL,
  fk_id_usuario INT          NOT NULL,
  PRIMARY KEY (id_registro),
  KEY idx_registroconsumo_insumo (fk_id_insumo),
  KEY idx_registroconsumo_area (fk_id_area),
  KEY idx_registroconsumo_usuario (fk_id_usuario),
  KEY idx_registroconsumo_data (data_hora),
  CONSTRAINT fk_registroconsumo_insumo  FOREIGN KEY (fk_id_insumo)  REFERENCES insumo (id_insumo),
  CONSTRAINT fk_registroconsumo_area    FOREIGN KEY (fk_id_area)    REFERENCES area (id_area),
  CONSTRAINT fk_registroconsumo_usuario FOREIGN KEY (fk_id_usuario) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_consumo_qtd CHECK (qtd_aplicada > 0)
) ENGINE=InnoDB;

-- =============================================================================
-- 6. HISTÓRICOS OPERACIONAIS (irrigação, leituras, alertas)
-- =============================================================================
CREATE TABLE hist_irrigacao (
  id_historico      BIGINT   NOT NULL AUTO_INCREMENT,
  fk_id_area        INT      NOT NULL,            -- no modelo lógico era VARCHAR(50): corrigido p/ INT
  fk_id_caixa       INT      NOT NULL,
  fk_id_usuario     INT      NULL COMMENT 'NULL = acionamento automático do Sistema',
  tempo_efetivo_min DOUBLE   NOT NULL COMMENT 'minutos (fracionário: o Java truncava para inteiro)',
  agua_usada_l      DOUBLE   NOT NULL,
  tipo_acionamento  ENUM('automatico','manual','forcado') NOT NULL,
  data_hora         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_historico),
  KEY idx_hist_area_data (fk_id_area, data_hora),
  KEY idx_hist_caixa (fk_id_caixa),
  CONSTRAINT fk_hist_area    FOREIGN KEY (fk_id_area)    REFERENCES area (id_area),
  CONSTRAINT fk_hist_caixa   FOREIGN KEY (fk_id_caixa)   REFERENCES caixa_dagua (id_caixa),
  CONSTRAINT fk_hist_usuario FOREIGN KEY (fk_id_usuario) REFERENCES usuario (id_usuario),
  CONSTRAINT ck_hist_valores CHECK (tempo_efetivo_min >= 0 AND agua_usada_l >= 0)
) ENGINE=InnoDB;

-- Série temporal de TODAS as leituras (alimenta gráficos e relatórios).
-- O PDF promete "histórico confiável de leituras de temperatura, umidade e pH",
-- mas o modelo lógico só guardava a última leitura.
CREATE TABLE leitura_sensor (
  id_leitura    BIGINT   NOT NULL AUTO_INCREMENT,
  fk_id_sensor  INT      NOT NULL,
  valor         DOUBLE   NOT NULL,
  data_hora     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  origem        ENUM('sensor','manual','sistema') NOT NULL DEFAULT 'sensor',
  fk_id_usuario INT      NULL,
  PRIMARY KEY (id_leitura),
  KEY idx_leitura_sensor_data (fk_id_sensor, data_hora),
  CONSTRAINT fk_leitura_sensor  FOREIGN KEY (fk_id_sensor)  REFERENCES sensor_controle (id_sensor_controle) ON DELETE CASCADE,
  CONSTRAINT fk_leitura_usuario FOREIGN KEY (fk_id_usuario) REFERENCES usuario (id_usuario)
) ENGINE=InnoDB;

-- Linha do tempo dos alertas (abre quando surge, fecha quando se resolve)
CREATE TABLE alerta (
  id_alerta    BIGINT NOT NULL AUTO_INCREMENT,
  fk_id_garden INT    NOT NULL,
  fk_id_area   INT    NULL,
  tipo         ENUM('nivel_baixo','irrigar','encharcado','ph_fora','culturas_incompativeis',
                    'ph_agua_fora','estoque_baixo','sensor_offline','temperatura_fora') NOT NULL,
  severidade   ENUM('info','atencao','critico') NOT NULL,
  chave        VARCHAR(60)  NOT NULL COMMENT 'identifica a condição, ex.: nivel_baixo:1',
  mensagem     VARCHAR(255) NOT NULL,
  criado_em    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolvido_em DATETIME NULL,
  chave_aberta VARCHAR(60) GENERATED ALWAYS AS (IF(resolvido_em IS NULL, chave, NULL)) STORED,
  PRIMARY KEY (id_alerta),
  UNIQUE KEY uk_alerta_aberto (fk_id_garden, chave_aberta),   -- no máx. 1 alerta ABERTO por condição
  KEY idx_alerta_data (fk_id_garden, criado_em),
  CONSTRAINT fk_alerta_garden FOREIGN KEY (fk_id_garden) REFERENCES garden (id_garden),
  CONSTRAINT fk_alerta_area   FOREIGN KEY (fk_id_area)   REFERENCES area (id_area) ON DELETE SET NULL
) ENGINE=InnoDB;

-- =============================================================================
-- 7. RELATÓRIOS = "FOTOGRAFIAS" DAS ABAS DO DASHBOARD, SEMPRE COM DATA E HORA
--    `relatorio` é o cabeçalho; cada aba tem sua tabela rel_*.
--    Os valores são COPIADOS (inclusive nomes e faixas ideais): se o catálogo
--    ou os limites mudarem amanhã, o relatório de ontem continua igual.
--    As colunas fk_* apontam para a origem só por referência (SET NULL).
-- =============================================================================
CREATE TABLE relatorio (
  id_relatorio     BIGINT   NOT NULL AUTO_INCREMENT,
  fk_id_garden     INT      NOT NULL,
  fk_id_usuario    INT      NULL COMMENT 'NULL + origem=agendado = gerado pelo Sistema',
  tipo             ENUM('completo','areas','plantas','irrigacao','sensores','insumos','alertas') NOT NULL DEFAULT 'completo',
  origem           ENUM('manual','agendado') NOT NULL DEFAULT 'manual',
  gerado_em        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  periodo_inicio   DATETIME NOT NULL COMMENT 'janela usada p/ consumo, irrigações e perdas',
  periodo_fim      DATETIME NOT NULL,
  garden_nome      VARCHAR(100) NOT NULL,
  usuario_nome     VARCHAR(100) NULL,
  irrigacao_nome   VARCHAR(50)  NULL,
  irrigacao_ligada TINYINT(1)   NULL,
  irrigacao_vazao_l DOUBLE      NULL,
  PRIMARY KEY (id_relatorio),
  KEY idx_relatorio_garden_data (fk_id_garden, gerado_em),
  KEY idx_relatorio_tipo_data (tipo, gerado_em),
  CONSTRAINT fk_relatorio_garden  FOREIGN KEY (fk_id_garden)  REFERENCES garden (id_garden),
  CONSTRAINT fk_relatorio_usuario FOREIGN KEY (fk_id_usuario) REFERENCES usuario (id_usuario) ON DELETE SET NULL,
  CONSTRAINT ck_relatorio_periodo CHECK (periodo_inicio <= periodo_fim)
) ENGINE=InnoDB;

-- aba Sensores / Ambiente
CREATE TABLE rel_sensor (
  id_rel_sensor BIGINT NOT NULL AUTO_INCREMENT,
  fk_id_relatorio BIGINT NOT NULL,
  fk_id_sensor  INT NULL,
  tipo          ENUM('umidade','ph_solo','ph_agua','nivel','ambiente') NOT NULL,
  `local`       VARCHAR(100) NOT NULL,
  area_nome     VARCHAR(50)  NULL,
  valor         DOUBLE NULL,
  unidade       VARCHAR(10) NULL,
  faixa_min     DOUBLE NULL,
  faixa_max     DOUBLE NULL,
  status        ENUM('ok','baixo','alto','sem_leitura','desatualizado') NOT NULL,
  lido_em       DATETIME NULL,
  PRIMARY KEY (id_rel_sensor),
  KEY idx_relsensor_rel (fk_id_relatorio),
  KEY idx_relsensor_sensor (fk_id_sensor),
  CONSTRAINT fk_relsensor_rel    FOREIGN KEY (fk_id_relatorio) REFERENCES relatorio (id_relatorio) ON DELETE CASCADE,
  CONSTRAINT fk_relsensor_sensor FOREIGN KEY (fk_id_sensor)    REFERENCES sensor_controle (id_sensor_controle) ON DELETE SET NULL
) ENGINE=InnoDB;

-- aba Irrigação (reservatórios) — o estado do sistema fica no cabeçalho
CREATE TABLE rel_reservatorio (
  id_rel_reservatorio BIGINT NOT NULL AUTO_INCREMENT,
  fk_id_relatorio BIGINT NOT NULL,
  fk_id_caixa     INT NULL,
  sensor_local    VARCHAR(100) NOT NULL,
  cap_l           DOUBLE NOT NULL,
  vol_atual_l     DOUBLE NOT NULL,
  nivel_pct       DOUBLE NOT NULL,
  limite_alerta_pct DOUBLE NOT NULL,
  autonomia_min   DOUBLE NULL COMMENT 'minutos de irrigação contínua na vazão nominal',
  status          ENUM('ok','baixo') NOT NULL,
  PRIMARY KEY (id_rel_reservatorio),
  KEY idx_relres_rel (fk_id_relatorio),
  KEY idx_relres_caixa (fk_id_caixa),
  CONSTRAINT fk_relres_rel   FOREIGN KEY (fk_id_relatorio) REFERENCES relatorio (id_relatorio) ON DELETE CASCADE,
  CONSTRAINT fk_relres_caixa FOREIGN KEY (fk_id_caixa)     REFERENCES caixa_dagua (id_caixa) ON DELETE SET NULL
) ENGINE=InnoDB;

-- aba Áreas de cultivo
CREATE TABLE rel_area (
  id_rel_area BIGINT NOT NULL AUTO_INCREMENT,
  fk_id_relatorio BIGINT NOT NULL,
  fk_id_area      INT NULL,
  area_nome       VARCHAR(50) NOT NULL,
  area_m2         DOUBLE NOT NULL,
  qtd_especies    INT NOT NULL,
  qtd_plantas     INT NOT NULL,
  umidade         DOUBLE NULL,
  umid_min_ideal  DOUBLE NULL,
  umid_max_ideal  DOUBLE NULL,
  status_umidade  ENUM('ok','seco','encharcado','incompativel','sem_leitura') NOT NULL,
  ph_solo         DOUBLE NULL,
  ph_min_ideal    DOUBLE NULL,
  ph_max_ideal    DOUBLE NULL,
  status_ph       ENUM('ok','baixo','alto','incompativel','sem_leitura') NOT NULL,
  volume_ideal_l  DOUBLE NOT NULL,
  precisa_irrigar TINYINT(1) NOT NULL,
  PRIMARY KEY (id_rel_area),
  KEY idx_relarea_rel (fk_id_relatorio),
  KEY idx_relarea_area (fk_id_area),
  CONSTRAINT fk_relarea_rel  FOREIGN KEY (fk_id_relatorio) REFERENCES relatorio (id_relatorio) ON DELETE CASCADE,
  CONSTRAINT fk_relarea_area FOREIGN KEY (fk_id_area)      REFERENCES area (id_area) ON DELETE SET NULL
) ENGINE=InnoDB;

-- aba Plantas
CREATE TABLE rel_area_planta (
  id_rel_area_planta BIGINT NOT NULL AUTO_INCREMENT,
  fk_id_relatorio BIGINT NOT NULL,
  fk_id_area      INT NULL,
  fk_id_planta    INT NULL,
  area_nome       VARCHAR(50)  NOT NULL,
  planta_nome     VARCHAR(100) NOT NULL,
  necessidade_agua VARCHAR(20) NOT NULL,
  necessidade_luz  VARCHAR(20) NOT NULL,
  ph_ideal_min    DOUBLE NOT NULL,
  ph_ideal_max    DOUBLE NOT NULL,
  nutricao        VARCHAR(10) NOT NULL,
  qtd_plantada    INT NOT NULL,
  qtd_atual       INT NOT NULL,
  estagios        JSON NULL COMMENT 'ex.: {"broto":20,"verde":20,"maduro":10}',
  data_plantio    DATE NULL,
  perdas_periodo  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id_rel_area_planta),
  KEY idx_relap_rel (fk_id_relatorio),
  CONSTRAINT fk_relap_rel     FOREIGN KEY (fk_id_relatorio) REFERENCES relatorio (id_relatorio) ON DELETE CASCADE,
  CONSTRAINT fk_relap_area    FOREIGN KEY (fk_id_area)      REFERENCES area (id_area) ON DELETE SET NULL,
  CONSTRAINT fk_relap_planta  FOREIGN KEY (fk_id_planta)    REFERENCES plantas (id_planta) ON DELETE SET NULL
) ENGINE=InnoDB;

-- aba Irrigação (resumo do período, por área)
CREATE TABLE rel_irrigacao (
  id_rel_irrigacao BIGINT NOT NULL AUTO_INCREMENT,
  fk_id_relatorio BIGINT NOT NULL,
  fk_id_area      INT NULL,
  area_nome       VARCHAR(50) NOT NULL,
  qtd_irrigacoes  INT    NOT NULL,
  litros_total    DOUBLE NOT NULL,
  minutos_total   DOUBLE NOT NULL,
  qtd_forcadas    INT    NOT NULL,
  ultima_irrigacao DATETIME NULL,
  PRIMARY KEY (id_rel_irrigacao),
  KEY idx_relirr_rel (fk_id_relatorio),
  CONSTRAINT fk_relirr_rel  FOREIGN KEY (fk_id_relatorio) REFERENCES relatorio (id_relatorio) ON DELETE CASCADE,
  CONSTRAINT fk_relirr_area FOREIGN KEY (fk_id_area)      REFERENCES area (id_area) ON DELETE SET NULL
) ENGINE=InnoDB;

-- aba Insumos / Estoque
CREATE TABLE rel_insumo (
  id_rel_insumo BIGINT NOT NULL AUTO_INCREMENT,
  fk_id_relatorio BIGINT NOT NULL,
  fk_id_insumo    INT NULL,
  nome_ins        VARCHAR(100) NOT NULL,
  categoria       VARCHAR(20)  NOT NULL,
  unidade         VARCHAR(10)  NOT NULL,
  estoque         DOUBLE NOT NULL,
  lmt_min         DOUBLE NULL,
  consumo_total   DOUBLE NOT NULL,
  consumo_periodo DOUBLE NOT NULL,
  status          ENUM('ok','baixo','zerado') NOT NULL,
  PRIMARY KEY (id_rel_insumo),
  KEY idx_relins_rel (fk_id_relatorio),
  CONSTRAINT fk_relins_rel    FOREIGN KEY (fk_id_relatorio) REFERENCES relatorio (id_relatorio) ON DELETE CASCADE,
  CONSTRAINT fk_relins_insumo FOREIGN KEY (fk_id_insumo)    REFERENCES insumo (id_insumo) ON DELETE SET NULL
) ENGINE=InnoDB;

-- aba Alertas (alertas ABERTOS no instante do relatório)
CREATE TABLE rel_alerta (
  id_rel_alerta BIGINT NOT NULL AUTO_INCREMENT,
  fk_id_relatorio BIGINT NOT NULL,
  fk_id_alerta    BIGINT NULL,
  fk_id_area      INT NULL,
  tipo            VARCHAR(30)  NOT NULL,
  severidade      VARCHAR(10)  NOT NULL,
  mensagem        VARCHAR(255) NOT NULL,
  aberto_desde    DATETIME NOT NULL,
  PRIMARY KEY (id_rel_alerta),
  KEY idx_relalerta_rel (fk_id_relatorio),
  CONSTRAINT fk_relalerta_rel    FOREIGN KEY (fk_id_relatorio) REFERENCES relatorio (id_relatorio) ON DELETE CASCADE,
  CONSTRAINT fk_relalerta_alerta FOREIGN KEY (fk_id_alerta)    REFERENCES alerta (id_alerta) ON DELETE SET NULL
) ENGINE=InnoDB;

-- =============================================================================
-- 8. TRIGGERS — regras que valem para QUALQUER caminho de acesso ao banco
-- =============================================================================
DELIMITER $$

-- 8.1 Valida a leitura de acordo com o tipo do sensor ---------------------------
CREATE TRIGGER trg_leitura_bi BEFORE INSERT ON leitura_sensor
FOR EACH ROW
BEGIN
  DECLARE v_tipo VARCHAR(20) DEFAULT NULL;
  DECLARE v_hmax DOUBLE DEFAULT NULL;

  SELECT tipo INTO v_tipo FROM sensor_controle WHERE id_sensor_controle = NEW.fk_id_sensor;

  IF v_tipo = 'umidade' AND (NEW.valor < 0 OR NEW.valor > 100) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Leitura de umidade fora de 0-100%.';
  ELSEIF v_tipo IN ('ph_solo','ph_agua') AND (NEW.valor < 0 OR NEW.valor > 14) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Leitura de pH fora de 0-14.';
  ELSEIF v_tipo = 'ambiente' AND (NEW.valor < -20 OR NEW.valor > 80) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Temperatura fora de -20 a 80 graus C.';
  ELSEIF v_tipo = 'nivel' THEN
    SELECT h_max INTO v_hmax FROM sensor_nivel WHERE id_sensor_controle = NEW.fk_id_sensor;
    IF NEW.valor < 0 OR NEW.valor > v_hmax THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Leitura de nivel fora de 0..h_max (revise a calibracao).';
    END IF;
  END IF;
END$$

-- 8.2 Atualiza o cache do sensor e o volume da caixa (se for sensor de nível) --
CREATE TRIGGER trg_leitura_ai AFTER INSERT ON leitura_sensor
FOR EACH ROW
BEGIN
  UPDATE sensor_controle
     SET ult_leitura = NEW.valor, ult_leitura_em = NEW.data_hora
   WHERE id_sensor_controle = NEW.fk_id_sensor
     AND (ult_leitura_em IS NULL OR ult_leitura_em <= NEW.data_hora);

  -- só recalcula o volume se esta for a leitura mais recente do sensor
  UPDATE caixa_dagua c
    JOIN sensor_nivel sn    ON sn.id_sensor_controle = c.fk_id_sensor_nivel
    JOIN sensor_controle sc ON sc.id_sensor_controle = c.fk_id_sensor_nivel
     SET c.vol_atual = ROUND(LEAST(c.cap_l, GREATEST(0, NEW.valor / sn.h_max * c.cap_l)), 3)   -- mL
   WHERE c.fk_id_sensor_nivel = NEW.fk_id_sensor
     AND sc.ult_leitura_em = NEW.data_hora;
END$$

-- 8.3 Capacidade máxima de espécies por área (regra "capacidade máxima atingida") -
CREATE TRIGGER trg_area_planta_bi BEFORE INSERT ON area_planta
FOR EACH ROW
BEGIN
  DECLARE v_max INT DEFAULT NULL;
  DECLARE v_qtd INT DEFAULT 0;
  SELECT max_especies INTO v_max FROM area WHERE id_area = NEW.fk_id_area;
  SELECT COUNT(*) INTO v_qtd FROM area_planta WHERE fk_id_area = NEW.fk_id_area;
  IF v_max IS NOT NULL AND v_qtd >= v_max THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Capacidade maxima de especies da area atingida.';
  END IF;
END$$

-- 8.4 Perda de plantas: valida e abate do estágio ---------------------------------
CREATE TRIGGER trg_perda_bi BEFORE INSERT ON registro_perda
FOR EACH ROW
BEGIN
  DECLARE v_disp INT DEFAULT NULL;
  SELECT quantidade INTO v_disp FROM area_planta_estagio
   WHERE fk_id_area = NEW.fk_id_area AND fk_id_planta = NEW.fk_id_planta
     AND fk_id_estagio = NEW.fk_id_estagio
     FOR UPDATE;
  IF v_disp IS NOT NULL AND v_disp < NEW.quantidade THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Perda maior que a quantidade existente no estagio.';
  END IF;
END$$

CREATE TRIGGER trg_perda_ai AFTER INSERT ON registro_perda
FOR EACH ROW
BEGIN
  UPDATE area_planta_estagio
     SET quantidade = quantidade - NEW.quantidade
   WHERE fk_id_area = NEW.fk_id_area AND fk_id_planta = NEW.fk_id_planta
     AND fk_id_estagio = NEW.fk_id_estagio;
END$$

-- 8.5 Consumo de insumo: valida estoque, abate e acumula --------------------------
CREATE TRIGGER trg_consumo_bi BEFORE INSERT ON registro_consumo
FOR EACH ROW
BEGIN
  DECLARE v_est  DOUBLE DEFAULT NULL;
  DECLARE v_nome VARCHAR(100) DEFAULT NULL;
  DECLARE v_g_ins INT DEFAULT NULL;
  DECLARE v_g_area INT DEFAULT NULL;
  DECLARE v_msg VARCHAR(128);

  SELECT estoque, nome_ins, fk_id_garden INTO v_est, v_nome, v_g_ins
    FROM insumo WHERE id_insumo = NEW.fk_id_insumo FOR UPDATE;
  SELECT fk_id_garden INTO v_g_area FROM area WHERE id_area = NEW.fk_id_area;

  IF v_est IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insumo nao cadastrado.';
  ELSEIF v_g_area IS NOT NULL AND v_g_ins <> v_g_area THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insumo e area pertencem a estufas diferentes.';
  ELSEIF v_est < NEW.qtd_aplicada THEN
    SET v_msg = CONCAT('Estoque insuficiente de ', v_nome);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

CREATE TRIGGER trg_consumo_ai AFTER INSERT ON registro_consumo
FOR EACH ROW
BEGIN
  UPDATE insumo
     SET estoque = estoque - NEW.qtd_aplicada,
         consumo_total = consumo_total + NEW.qtd_aplicada
   WHERE id_insumo = NEW.fk_id_insumo;
END$$

-- 8.6 Entrada de estoque ------------------------------------------------------------
CREATE TRIGGER trg_entrada_ai AFTER INSERT ON entrada_insumo
FOR EACH ROW
BEGIN
  UPDATE insumo SET estoque = estoque + NEW.quantidade WHERE id_insumo = NEW.fk_id_insumo;
END$$

DELIMITER ;

-- =============================================================================
-- MIGRAÇÃO DE `usuario` (rode SOMENTE se a tabela já existia na estrutura antiga,
-- com apenas id_usuario, email e senha). Em instalação nova, ignore este bloco.
-- =============================================================================
-- ALTER TABLE usuario
--   ADD COLUMN nome_comp VARCHAR(100) NOT NULL DEFAULT '' AFTER id_usuario,
--   ADD COLUMN status    ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
--   ADD COLUMN criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;
