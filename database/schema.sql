-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: GIE_DATA
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `area`
--

DROP TABLE IF EXISTS `area`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `area` (
  `id_area` int NOT NULL AUTO_INCREMENT,
  `area_m2` double DEFAULT NULL,
  `fk_id_garden` int NOT NULL,
  `fk_id_sensor_umidade` int NOT NULL,
  `fk_id_sensor_ph_solo` int NOT NULL,
  PRIMARY KEY (`id_area`),
  UNIQUE KEY `uk_area_sensor_umidade` (`fk_id_sensor_umidade`),
  UNIQUE KEY `uk_area_sensor_ph_solo` (`fk_id_sensor_ph_solo`),
  KEY `idx_area_garden` (`fk_id_garden`),
  CONSTRAINT `fk_area_garden` FOREIGN KEY (`fk_id_garden`) REFERENCES `garden` (`id_garden`),
  CONSTRAINT `fk_area_sensor_ph_solo` FOREIGN KEY (`fk_id_sensor_ph_solo`) REFERENCES `sensor_ph_solo` (`id_sensor_controle`),
  CONSTRAINT `fk_area_sensor_umidade` FOREIGN KEY (`fk_id_sensor_umidade`) REFERENCES `sensor_umidade` (`id_sensor_controle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `area_planta`
--

DROP TABLE IF EXISTS `area_planta`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `area_planta` (
  `fk_id_area` int NOT NULL,
  `fk_id_planta` int NOT NULL,
  `qtd_plantada` int DEFAULT NULL,
  `data` date DEFAULT NULL,
  PRIMARY KEY (`fk_id_area`,`fk_id_planta`),
  KEY `idx_areaplanta_planta` (`fk_id_planta`),
  CONSTRAINT `fk_areaplanta_area` FOREIGN KEY (`fk_id_area`) REFERENCES `area` (`id_area`) ON DELETE CASCADE,
  CONSTRAINT `fk_areaplanta_planta` FOREIGN KEY (`fk_id_planta`) REFERENCES `plantas` (`id_planta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `caixa_dagua`
--

DROP TABLE IF EXISTS `caixa_dagua`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `caixa_dagua` (
  `id_caixa` int NOT NULL AUTO_INCREMENT,
  `cap_l` double DEFAULT NULL,
  `vol_atual` double DEFAULT NULL,
  `fk_id_garden` int NOT NULL,
  `fk_id_sensor_nivel` int NOT NULL,
  PRIMARY KEY (`id_caixa`),
  UNIQUE KEY `uk_caixa_sensor_nivel` (`fk_id_sensor_nivel`),
  KEY `idx_caixa_garden` (`fk_id_garden`),
  CONSTRAINT `fk_caixa_garden` FOREIGN KEY (`fk_id_garden`) REFERENCES `garden` (`id_garden`),
  CONSTRAINT `fk_caixa_sensor_nivel` FOREIGN KEY (`fk_id_sensor_nivel`) REFERENCES `sensor_nivel` (`id_sensor_controle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `garden`
--

DROP TABLE IF EXISTS `garden`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `garden` (
  `id_garden` int NOT NULL AUTO_INCREMENT,
  `nome` varchar(100) NOT NULL,
  `fk_id_sensor_ambiente` int NOT NULL,
  `fk_id_sensor_ph_agua` int NOT NULL,
  `fk_id_sist_irriga` int NOT NULL,
  PRIMARY KEY (`id_garden`),
  UNIQUE KEY `uk_garden_sensor_ambiente` (`fk_id_sensor_ambiente`),
  UNIQUE KEY `uk_garden_sensor_ph_agua` (`fk_id_sensor_ph_agua`),
  UNIQUE KEY `uk_garden_sist_irriga` (`fk_id_sist_irriga`),
  CONSTRAINT `fk_garden_sensor_ph_agua` FOREIGN KEY (`fk_id_sensor_ph_agua`) REFERENCES `sensor_ph_agua` (`id_sensor_controle`),
  CONSTRAINT `fk_garden_sist_irriga` FOREIGN KEY (`fk_id_sist_irriga`) REFERENCES `sistema_irrigacao` (`id_sis_irr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `insumo`
--

DROP TABLE IF EXISTS `insumo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `insumo` (
  `id_insumo` int NOT NULL AUTO_INCREMENT,
  `nome_ins` varchar(100) NOT NULL,
  `estoque` double NOT NULL DEFAULT '0',
  `lmt_min` double DEFAULT NULL,
  `consumo_total` double NOT NULL DEFAULT '0',
  PRIMARY KEY (`id_insumo`),
  UNIQUE KEY `uk_insumo_nome` (`nome_ins`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `perfil`
--

DROP TABLE IF EXISTS `perfil`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `perfil` (
  `id_perfil` int NOT NULL AUTO_INCREMENT,
  `nome_perfil` varchar(50) NOT NULL,
  PRIMARY KEY (`id_perfil`),
  UNIQUE KEY `uk_perfil_nome` (`nome_perfil`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `plantas`
--

DROP TABLE IF EXISTS `plantas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantas` (
  `id_planta` int NOT NULL AUTO_INCREMENT,
  `nome_p` varchar(100) NOT NULL,
  `necessidade_agua` varchar(20) DEFAULT NULL,
  `necessidade_luz` varchar(20) DEFAULT NULL,
  `ph_ideal_min` double DEFAULT NULL,
  `ph_ideal_max` double DEFAULT NULL,
  `nutricao` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`id_planta`),
  UNIQUE KEY `uk_plantas_nome` (`nome_p`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `registro_consumo`
--

DROP TABLE IF EXISTS `registro_consumo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `registro_consumo` (
  `id_registro` int NOT NULL AUTO_INCREMENT,
  `qtd_aplicada` double NOT NULL,
  `data_hora` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `motivo` varchar(25) DEFAULT NULL,
  `fk_id_insumo` int NOT NULL,
  `fk_id_area` int NOT NULL,
  `fk_id_usuario` int NOT NULL,
  PRIMARY KEY (`id_registro`),
  KEY `idx_registroconsumo_insumo` (`fk_id_insumo`),
  KEY `idx_registroconsumo_area` (`fk_id_area`),
  KEY `idx_registroconsumo_usuario` (`fk_id_usuario`),
  KEY `idx_registroconsumo_data` (`data_hora`),
  CONSTRAINT `fk_registroconsumo_area` FOREIGN KEY (`fk_id_area`) REFERENCES `area` (`id_area`),
  CONSTRAINT `fk_registroconsumo_insumo` FOREIGN KEY (`fk_id_insumo`) REFERENCES `insumo` (`id_insumo`),
  CONSTRAINT `fk_registroconsumo_usuario` FOREIGN KEY (`fk_id_usuario`) REFERENCES `usuario` (`id_usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sensor_ambiente`
--

DROP TABLE IF EXISTS `sensor_ambiente`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensor_ambiente` (
  `id_sensor_controle` int NOT NULL,
  `temp` double NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_ambiente_sensor` FOREIGN KEY (`id_sensor_controle`) REFERENCES `sensor_controle` (`id_sensor_controle`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sensor_controle`
--

DROP TABLE IF EXISTS `sensor_controle`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensor_controle` (
  `id_sensor_controle` int NOT NULL AUTO_INCREMENT,
  `local` varchar(100) NOT NULL,
  `ult_leitura` double DEFAULT NULL,
  `tipo` varchar(50) NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  KEY `idx_sensor_controle_tipo` (`tipo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sensor_nivel`
--

DROP TABLE IF EXISTS `sensor_nivel`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensor_nivel` (
  `id_sensor_controle` int NOT NULL,
  `h_max` double NOT NULL COMMENT 'Nivel maximo da caixa dagua. Era "ph_max" no script original, o que nao fazia sentido para este sensor.',
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_nivel_sensor` FOREIGN KEY (`id_sensor_controle`) REFERENCES `sensor_controle` (`id_sensor_controle`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sensor_ph_agua`
--

DROP TABLE IF EXISTS `sensor_ph_agua`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensor_ph_agua` (
  `id_sensor_controle` int NOT NULL,
  `ph_min` double NOT NULL,
  `ph_max` double NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_ph_agua_sensor` FOREIGN KEY (`id_sensor_controle`) REFERENCES `sensor_controle` (`id_sensor_controle`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sensor_ph_solo`
--

DROP TABLE IF EXISTS `sensor_ph_solo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensor_ph_solo` (
  `id_sensor_controle` int NOT NULL,
  `phs_min` double NOT NULL,
  `phs_max` double NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_ph_solo_sensor` FOREIGN KEY (`id_sensor_controle`) REFERENCES `sensor_controle` (`id_sensor_controle`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sensor_umidade`
--

DROP TABLE IF EXISTS `sensor_umidade`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensor_umidade` (
  `id_sensor_controle` int NOT NULL,
  `umid_min` double NOT NULL,
  `umid_max` double NOT NULL,
  PRIMARY KEY (`id_sensor_controle`),
  CONSTRAINT `fk_umidade_sensor` FOREIGN KEY (`id_sensor_controle`) REFERENCES `sensor_controle` (`id_sensor_controle`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sistema_irrigacao`
--

DROP TABLE IF EXISTS `sistema_irrigacao`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sistema_irrigacao` (
  `id_sis_irr` int NOT NULL AUTO_INCREMENT,
  `nome` varchar(50) NOT NULL,
  `lig_bol` tinyint(1) NOT NULL DEFAULT '0',
  `vazao_l` double NOT NULL,
  PRIMARY KEY (`id_sis_irr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `usuario`
--

DROP TABLE IF EXISTS `usuario`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuario` (
  `id_usuario` int NOT NULL AUTO_INCREMENT,
  `email` varchar(50) NOT NULL,
  `senha` varchar(200) NOT NULL,
  PRIMARY KEY (`id_usuario`),
  UNIQUE KEY `uk_usuario_login` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-05 23:40:18
