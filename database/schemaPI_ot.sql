

SET FOREIGN_KEY_CHECKS = 0;


DROP TABLE IF EXISTS `hist_irrigacao`;
DROP TABLE IF EXISTS `registro_consumo`;
DROP TABLE IF EXISTS `area_planta`;
DROP TABLE IF EXISTS `caixa_dagua`;
DROP TABLE IF EXISTS `area`;
DROP TABLE IF EXISTS `garden`;
DROP TABLE IF EXISTS `sistema_irrigacao`;
DROP TABLE IF EXISTS `sensor_ambiente`;
DROP TABLE IF EXISTS `sensor_nivel`;
DROP TABLE IF EXISTS `sensor_ph_agua`;
DROP TABLE IF EXISTS `sensor_ph_solo`;
DROP TABLE IF EXISTS `sensor_umidade`;
DROP TABLE IF EXISTS `sensor_controle`;
DROP TABLE IF EXISTS `plantas`;
DROP TABLE IF EXISTS `insumo`;
DROP TABLE IF EXISTS `usuario`;
DROP TABLE IF EXISTS `perfil`;

-- ---------------------------------------------------------------------
-- perfil (perfil de acesso do usuário)
-- ---------------------------------------------------------------------
CREATE TABLE `perfil` (
  `id_perfil`   INT NOT NULL AUTO_INCREMENT,
  `nome_perfil` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`id_perfil`),
  UNIQUE KEY `uk_perfil_nome` (`nome_perfil`)
);

-- ---------------------------------------------------------------------
-- usuario
-- ---------------------------------------------------------------------
CREATE TABLE `usuario` (
  `id_usuario`   INT NOT NULL AUTO_INCREMENT,
  `nome_comp`    VARCHAR(100) NOT NULL,
  `login`        VARCHAR(50)  NOT NULL,
  `senha`        VARCHAR(200) NOT NULL,
  `status`       VARCHAR(10)  NOT NULL DEFAULT 'ativo',
  `fk_id_perfil` INT NOT NULL,
  PRIMARY KEY (`id_usuario`),
  UNIQUE KEY `uk_usuario_login` (`login`),
  KEY `idx_usuario_perfil` (`fk_id_perfil`),
  CONSTRAINT `fk_usuario_perfil` FOREIGN KEY (`fk_id_perfil`)
    REFERENCES `perfil` (`id_perfil`)
    ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- sensor_controle (supertipo: todo sensor físico tem 1 linha aqui)
-- ---------------------------------------------------------------------
CREATE TABLE `sensor_controle` (
  `id_sensor_controle` INT NOT NULL AUTO_INCREMENT,
  `local`       VARCHAR(100) NOT NULL,
  `ult_leitura` DOUBLE DEFAULT NULL,
  `tipo`        VARCHAR(50) NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  KEY `idx_sensor_controle_tipo` (`tipo`)
);

-- ---------------------------------------------------------------------
-- Subtipos de sensor_controle: cada um reaproveita o mesmo
-- id_sensor_controle do "pai" como PK e FK (1 sensor = 1 tipo).
-- ---------------------------------------------------------------------
CREATE TABLE `sensor_umidade` (
  `id_sensor_controle` INT NOT NULL,
  `umid_min` DOUBLE NOT NULL,
  `umid_max` DOUBLE NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_umidade_sensor` FOREIGN KEY (`id_sensor_controle`)
    REFERENCES `sensor_controle` (`id_sensor_controle`)
    ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `sensor_ph_solo` (
  `id_sensor_controle` INT NOT NULL,
  `phs_min` DOUBLE NOT NULL,
  `phs_max` DOUBLE NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_ph_solo_sensor` FOREIGN KEY (`id_sensor_controle`)
    REFERENCES `sensor_controle` (`id_sensor_controle`)
    ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `sensor_ph_agua` (
  `id_sensor_controle` INT NOT NULL,
  `ph_min` DOUBLE NOT NULL,
  `ph_max` DOUBLE NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_ph_agua_sensor` FOREIGN KEY (`id_sensor_controle`)
    REFERENCES `sensor_controle` (`id_sensor_controle`)
    ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `sensor_nivel` (
  `id_sensor_controle` INT NOT NULL,
  `h_max` DOUBLE NOT NULL COMMENT 'Nivel maximo da caixa dagua. Era "ph_max" no script original, o que nao fazia sentido para este sensor.',
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_nivel_sensor` FOREIGN KEY (`id_sensor_controle`)
    REFERENCES `sensor_controle` (`id_sensor_controle`)
    ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `sensor_ambiente` (
  `id_sensor_controle` INT NOT NULL,
  `temp` DOUBLE NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_ambiente_sensor` FOREIGN KEY (`id_sensor_controle`)
    REFERENCES `sensor_controle` (`id_sensor_controle`)
    ON UPDATE CASCADE ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- sistema_irrigacao
-- ---------------------------------------------------------------------
CREATE TABLE `sistema_irrigacao` (
  `id_sis_irr` INT NOT NULL AUTO_INCREMENT,
  `nome`       VARCHAR(50) NOT NULL,
  `lig_bol`    BOOLEAN NOT NULL DEFAULT FALSE,
  `vazao_l`    DOUBLE NOT NULL,
  PRIMARY KEY (`id_sis_irr`)
);

-- ---------------------------------------------------------------------
-- garden 
-- ---------------------------------------------------------------------
CREATE TABLE `garden` (
  `id_garden`             INT NOT NULL AUTO_INCREMENT,
  `nome`                  VARCHAR(100) NOT NULL,
  `fk_id_sensor_ambiente` INT NOT NULL,
  `fk_id_sensor_ph_agua`  INT NOT NULL,
  `fk_id_sist_irriga`     INT NOT NULL,
  PRIMARY KEY (`id_garden`),
  UNIQUE KEY `uk_garden_sensor_ambiente` (`fk_id_sensor_ambiente`),
  UNIQUE KEY `uk_garden_sensor_ph_agua` (`fk_id_sensor_ph_agua`),
  UNIQUE KEY `uk_garden_sist_irriga` (`fk_id_sist_irriga`),
  CONSTRAINT `fk_garden_sensor_ambiente` FOREIGN KEY (`fk_id_sensor_ambiente`)
    REFERENCES `sensor_ambiente` (`id_sensor_controle`),
  CONSTRAINT `fk_garden_sensor_ph_agua` FOREIGN KEY (`fk_id_sensor_ph_agua`)
    REFERENCES `sensor_ph_agua` (`id_sensor_controle`),
  CONSTRAINT `fk_garden_sist_irriga` FOREIGN KEY (`fk_id_sist_irriga`)
    REFERENCES `sistema_irrigacao` (`id_sis_irr`)
);

-- ---------------------------------------------------------------------
-- area
-- ---------------------------------------------------------------------
CREATE TABLE `area` (
  `id_area`              INT NOT NULL AUTO_INCREMENT,
  `area_m2`              DOUBLE DEFAULT NULL,
  `fk_id_garden`         INT NOT NULL,
  `fk_id_sensor_umidade` INT NOT NULL,
  `fk_id_sensor_ph_solo` INT NOT NULL,
  PRIMARY KEY (`id_area`),
  UNIQUE KEY `uk_area_sensor_umidade` (`fk_id_sensor_umidade`),
  UNIQUE KEY `uk_area_sensor_ph_solo` (`fk_id_sensor_ph_solo`),
  KEY `idx_area_garden` (`fk_id_garden`),
  CONSTRAINT `fk_area_garden` FOREIGN KEY (`fk_id_garden`)
    REFERENCES `garden` (`id_garden`),
  CONSTRAINT `fk_area_sensor_umidade` FOREIGN KEY (`fk_id_sensor_umidade`)
    REFERENCES `sensor_umidade` (`id_sensor_controle`),
  CONSTRAINT `fk_area_sensor_ph_solo` FOREIGN KEY (`fk_id_sensor_ph_solo`)
    REFERENCES `sensor_ph_solo` (`id_sensor_controle`)
);

-- ---------------------------------------------------------------------
-- caixa_dagua
-- ---------------------------------------------------------------------
CREATE TABLE `caixa_dagua` (
  `id_caixa`           INT NOT NULL AUTO_INCREMENT,
  `cap_l`              DOUBLE DEFAULT NULL,
  `vol_atual`          DOUBLE DEFAULT NULL,
  `fk_id_garden`       INT NOT NULL,
  `fk_id_sensor_nivel` INT NOT NULL,
  PRIMARY KEY (`id_caixa`),
  KEY `idx_caixa_garden` (`fk_id_garden`),
  UNIQUE KEY `uk_caixa_sensor_nivel` (`fk_id_sensor_nivel`),
  CONSTRAINT `fk_caixa_garden` FOREIGN KEY (`fk_id_garden`)
    REFERENCES `garden` (`id_garden`),
  CONSTRAINT `fk_caixa_sensor_nivel` FOREIGN KEY (`fk_id_sensor_nivel`)
    REFERENCES `sensor_nivel` (`id_sensor_controle`)
);

-- ---------------------------------------------------------------------
-- plantas
-- ---------------------------------------------------------------------
CREATE TABLE `plantas` (
  `id_planta`        INT NOT NULL AUTO_INCREMENT,
  `nome_p`           VARCHAR(100) NOT NULL,
  `necessidade_agua` VARCHAR(20) DEFAULT NULL,
  `necessidade_luz`  VARCHAR(20) DEFAULT NULL,
  `ph_ideal_min`     DOUBLE DEFAULT NULL,
  `ph_ideal_max`     DOUBLE DEFAULT NULL,
  `nutricao`         VARCHAR(30) DEFAULT NULL,
  PRIMARY KEY (`id_planta`),
  UNIQUE KEY `uk_plantas_nome` (`nome_p`)
);

-- ---------------------------------------------------------------------
-- area_planta (associativa entre area e plantas)
-- Correção: coluna `id_area` renomeada para `fk_id_area` (é FK, o
-- prefixo estava inconsistente com `fk_id_planta` na mesma tabela).
-- ---------------------------------------------------------------------
CREATE TABLE `area_planta` (
  `fk_id_area`   INT NOT NULL,
  `fk_id_planta` INT NOT NULL,
  `qtd_plantada` INT DEFAULT NULL,
  `data`         DATE DEFAULT NULL,
  PRIMARY KEY (`fk_id_area`, `fk_id_planta`),
  KEY `idx_areaplanta_planta` (`fk_id_planta`),
  CONSTRAINT `fk_areaplanta_area` FOREIGN KEY (`fk_id_area`)
    REFERENCES `area` (`id_area`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_areaplanta_planta` FOREIGN KEY (`fk_id_planta`)
    REFERENCES `plantas` (`id_planta`)
);

-- ---------------------------------------------------------------------
-- insumo
-- ---------------------------------------------------------------------
CREATE TABLE `insumo` (
  `id_insumo`     INT NOT NULL AUTO_INCREMENT,
  `nome_ins`      VARCHAR(100) NOT NULL,
  `estoque`       DOUBLE NOT NULL DEFAULT 0,
  `lmt_min`       DOUBLE DEFAULT NULL,
  `consumo_total` DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (`id_insumo`),
  UNIQUE KEY `uk_insumo_nome` (`nome_ins`)
);

-- ---------------------------------------------------------------------
-- registro_consumo

-- ---------------------------------------------------------------------
CREATE TABLE `registro_consumo` (
  `id_registro`   INT NOT NULL AUTO_INCREMENT,
  `qtd_aplicada`  DOUBLE NOT NULL,
  `data_hora`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `motivo`        VARCHAR(25) DEFAULT NULL,
  `fk_id_insumo`  INT NOT NULL,
  `fk_id_area`    INT NOT NULL,
  `fk_id_usuario` INT NOT NULL,
  PRIMARY KEY (`id_registro`),
  KEY `idx_registroconsumo_insumo` (`fk_id_insumo`),
  KEY `idx_registroconsumo_area` (`fk_id_area`),
  KEY `idx_registroconsumo_usuario` (`fk_id_usuario`),
  KEY `idx_registroconsumo_data` (`data_hora`),
  CONSTRAINT `fk_registroconsumo_insumo` FOREIGN KEY (`fk_id_insumo`)
    REFERENCES `insumo` (`id_insumo`),
  CONSTRAINT `fk_registroconsumo_area` FOREIGN KEY (`fk_id_area`)
    REFERENCES `area` (`id_area`),
  CONSTRAINT `fk_registroconsumo_usuario` FOREIGN KEY (`fk_id_usuario`)
    REFERENCES `usuario` (`id_usuario`)
);

-- ---------------------------------------------------------------------
-- hist_irrigacao

-- ---------------------------------------------------------------------
CREATE TABLE `hist_irrigacao` (
  `id_historico`        INT NOT NULL AUTO_INCREMENT,
  `tempo_efetivo_minut` INT DEFAULT NULL,
  `agua_usada`          DOUBLE DEFAULT NULL,
  `tipo_acionamento`    VARCHAR(10) DEFAULT NULL,
  `data_hora`           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fk_id_area`          INT NOT NULL,
  `fk_id_caixa`         INT NOT NULL,
  PRIMARY KEY (`id_historico`),
  KEY `idx_histirrigacao_area` (`fk_id_area`),
  KEY `idx_histirrigacao_caixa` (`fk_id_caixa`),
  KEY `idx_histirrigacao_data` (`data_hora`),
  CONSTRAINT `fk_histirrigacao_area` FOREIGN KEY (`fk_id_area`)
    REFERENCES `area` (`id_area`),
  CONSTRAINT `fk_histirrigacao_caixa` FOREIGN KEY (`fk_id_caixa`)
    REFERENCES `caixa_dagua` (`id_caixa`);

SET FOREIGN_KEY_CHECKS = 1;
