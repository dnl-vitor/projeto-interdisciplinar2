-- Troque pelo nome do seu novo banco:
CREATE DATABASE IF NOT EXISTS GIE_DATA CHARACTER SET utf8mb4;
USE GIE_DATA;

-- ---------------------------------------------------------
-- plantas: catálogo de espécies (o que cada planta precisa)
-- ---------------------------------------------------------
CREATE TABLE plantas (
    id_planta        INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nome             VARCHAR(100) NOT NULL,
    necessidade_agua ENUM('baixa','media','alta') NOT NULL,
    necessidade_luz  ENUM('sol_pleno','meia_sombra','sombra') NOT NULL,
    ph_ideal_min     DECIMAL(3,1) NOT NULL,
    ph_ideal_max     DECIMAL(3,1) NOT NULL,
    nutricao         ENUM('baixa','media','alta') NOT NULL,
    CONSTRAINT uq_plantas_nome UNIQUE (nome),
    CONSTRAINT ck_plantas_ph CHECK (
        ph_ideal_min >= 0 AND ph_ideal_max <= 14 AND ph_ideal_min <= ph_ideal_max
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------
-- areas: canteiros dentro de uma estufa
-- id_estufa vale 1 se você não informar (só há uma estufa por enquanto).
-- Os sensores são opcionais (NULL) e cada sensor serve a uma só área.
-- ---------------------------------------------------------
CREATE TABLE areas (
    id_area           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_estufa         INT UNSIGNED NOT NULL DEFAULT 1,
    nome              VARCHAR(80)  NOT NULL,
    area_m2           DECIMAL(8,2) NULL,
    umidade_ideal_min TINYINT UNSIGNED NOT NULL,
    umidade_ideal_max TINYINT UNSIGNED NOT NULL,
    ph_ideal_min      DECIMAL(3,1) NOT NULL,
    ph_ideal_max      DECIMAL(3,1) NOT NULL,
    id_sensor_umidade INT UNSIGNED NULL,
    id_sensor_ph      INT UNSIGNED NULL,
    criado_em         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_areas_estufa_nome    UNIQUE (id_estufa, nome),
    CONSTRAINT uq_areas_sensor_umidade UNIQUE (id_sensor_umidade),
    CONSTRAINT uq_areas_sensor_ph      UNIQUE (id_sensor_ph),
    CONSTRAINT ck_areas_umidade CHECK (
        umidade_ideal_min <= umidade_ideal_max AND umidade_ideal_max <= 100
    ),
    CONSTRAINT ck_areas_ph CHECK (
        ph_ideal_min >= 0 AND ph_ideal_max <= 14 AND ph_ideal_min <= ph_ideal_max
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------
-- plantios: o que está (ou esteve) plantado em cada área.
-- Cada plantio é uma linha, então replantar a mesma espécie
-- na mesma área não apaga o histórico.
-- Sem FK, os índices abaixo mantêm as consultas por área e por planta rápidas.
-- ---------------------------------------------------------
CREATE TABLE plantios (
    id_plantio    INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    id_area       INT UNSIGNED NOT NULL,
    id_planta     INT UNSIGNED NOT NULL,
    qtd_plantada  INT UNSIGNED NOT NULL,
    data_plantio  DATE NOT NULL,
    status        ENUM('ativo','colhido') NOT NULL DEFAULT 'ativo',
    data_colheita DATE NULL,
    INDEX idx_plantios_area_status (id_area, status),
    INDEX idx_plantios_planta (id_planta),
    CONSTRAINT ck_plantios_qtd CHECK (qtd_plantada > 0),
    CONSTRAINT ck_plantios_datas CHECK (data_colheita IS NULL OR data_colheita >= data_plantio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------
-- (Opcional) Compatibilidade das plantas ativas de cada área.
-- ph_compativel = 0 quando as faixas de pH das plantas não se cruzam.
-- niveis_de_agua > 1 indica plantas com necessidades de água diferentes.
-- ---------------------------------------------------------
CREATE VIEW vw_compatibilidade_area AS
SELECT
    a.id_area,
    a.nome                                   AS area,
    COUNT(pl.id_planta)                      AS plantas_ativas,
    MAX(pl.ph_ideal_min)                     AS ph_comum_min,
    MIN(pl.ph_ideal_max)                     AS ph_comum_max,
    COALESCE(MAX(pl.ph_ideal_min) <= MIN(pl.ph_ideal_max), 1) AS ph_compativel,
    COUNT(DISTINCT pl.necessidade_agua)      AS niveis_de_agua
FROM areas a
LEFT JOIN plantios p  ON p.id_area = a.id_area AND p.status = 'ativo'
LEFT JOIN plantas  pl ON pl.id_planta = p.id_planta
GROUP BY a.id_area, a.nome;

-- ---------------------------------------------------------
-- (Opcional) Dados de exemplo iguais ao protótipo da aba
-- Áreas e Culturas. Rode só em banco novo (usa ids 1, 2, 3).
-- ---------------------------------------------------------
INSERT INTO plantas (nome, necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao) VALUES
    ('Tomate', 'media', 'sol_pleno',   6.0, 7.0, 'alta'),
    ('Alface', 'alta',  'meia_sombra', 6.0, 7.5, 'media'),
    ('Cacto',  'baixa', 'sol_pleno',   7.0, 8.0, 'baixa');

INSERT INTO areas (nome, umidade_ideal_min, umidade_ideal_max, ph_ideal_min, ph_ideal_max)
VALUES ('Canteiro A', 30, 70, 6.0, 7.0);

INSERT INTO plantios (id_area, id_planta, qtd_plantada, data_plantio) VALUES
    (1, 1, 12, CURDATE()),
    (1, 2, 20, CURDATE()),
    (1, 3,  3, CURDATE());

-- ---------------------------------------------------------
-- PARA DEPOIS: chaves estrangeiras
-- Descomente quando criar as tabelas estufas e sensores e a modelagem
-- estiver fechada. Antes, confira se não há ids órfãos nas tabelas.
-- ---------------------------------------------------------
-- ALTER TABLE areas
--     ADD CONSTRAINT fk_areas_estufa          FOREIGN KEY (id_estufa)         REFERENCES estufas (id_estufa)  ON DELETE RESTRICT,
--     ADD CONSTRAINT fk_areas_sensor_umidade  FOREIGN KEY (id_sensor_umidade) REFERENCES sensores (id_sensor) ON DELETE SET NULL,
--     ADD CONSTRAINT fk_areas_sensor_ph       FOREIGN KEY (id_sensor_ph)      REFERENCES sensores (id_sensor) ON DELETE SET NULL;
--
-- ALTER TABLE plantios
--     ADD CONSTRAINT fk_plantios_area   FOREIGN KEY (id_area)   REFERENCES areas (id_area)     ON DELETE CASCADE,
--     ADD CONSTRAINT fk_plantios_planta FOREIGN KEY (id_planta) REFERENCES plantas (id_planta) ON DELETE RESTRICT;
