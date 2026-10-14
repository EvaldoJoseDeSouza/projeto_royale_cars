-- =====================================================================
--  ROYALE CARS - Sistema de Gestão de Locadora de Veículos
--  Banco de dados: royale_cars
--  Compatível com MariaDB 10.4+ (XAMPP) e MySQL 8+
--
--  ATENÇÃO: este script APAGA e recria todas as tabelas do sistema.
--  As datas dos dados de exemplo são calculadas a partir do dia em que
--  o script é importado, então o sistema sempre parece "atual".
--
--  As regras mais importantes também ficam no banco (CHECK, UNIQUE e
--  chaves estrangeiras). Assim, mesmo que alguém envie dados direto ao
--  servidor, sem passar pela tela, o banco recusa o que for inválido.
-- =====================================================================

SET NAMES utf8mb4;
SET time_zone = '-03:00';
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS `royale_cars`
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_general_ci;

USE `royale_cars`;

DROP TABLE IF EXISTS `logs`;
DROP TABLE IF EXISTS `login_tentativas`;
DROP TABLE IF EXISTS `manutencoes`;
DROP TABLE IF EXISTS `locacoes`;
DROP TABLE IF EXISTS `veiculos`;
DROP TABLE IF EXISTS `clientes`;
DROP TABLE IF EXISTS `usuario_permissoes`;
DROP TABLE IF EXISTS `usuarios`;

SET FOREIGN_KEY_CHECKS = 1;


-- ---------------------------------------------------------------------
-- USUÁRIOS (chefe, gerentes e funcionários)
-- ---------------------------------------------------------------------

CREATE TABLE `usuarios` (
    `id`            INT          NOT NULL AUTO_INCREMENT,
    `nome`          VARCHAR(100) NOT NULL,
    `email`         VARCHAR(150) NOT NULL,
    `senha`         VARCHAR(255) NOT NULL,
    `cargo`         ENUM('chefe','gerente','funcionario') NOT NULL DEFAULT 'funcionario',
    `ativo`         TINYINT(1)   NOT NULL DEFAULT 1,
    `trocar_senha`  TINYINT(1)   NOT NULL DEFAULT 0,
    `ultimo_acesso` DATETIME     NULL,
    `criado_em`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `atualizado_em` TIMESTAMP    NULL ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_usuarios_email` (`email`),

    CONSTRAINT `ck_usuarios_nome`  CHECK (CHAR_LENGTH(TRIM(`nome`)) >= 3),
    CONSTRAINT `ck_usuarios_email` CHECK (`email` LIKE '_%@_%._%'),
    CONSTRAINT `ck_usuarios_ativo` CHECK (`ativo` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- Permissões individuais de cada usuário.
-- O chefe tem acesso total e não precisa de linhas aqui.

CREATE TABLE `usuario_permissoes` (
    `usuario_id` INT         NOT NULL,
    `permissao`  VARCHAR(50) NOT NULL,

    PRIMARY KEY (`usuario_id`, `permissao`),

    CONSTRAINT `fk_permissoes_usuario`
        FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------------------
-- CLIENTES
-- CPF, CNH e telefone são guardados só com números.
-- ---------------------------------------------------------------------

CREATE TABLE `clientes` (
    `id`            INT          NOT NULL AUTO_INCREMENT,
    `nome`          VARCHAR(150) NOT NULL,
    `cpf`           CHAR(11)     NOT NULL,
    `cnh`           CHAR(11)     NOT NULL,
    `cnh_validade`  DATE         NOT NULL,
    `email`         VARCHAR(150) NOT NULL,
    `telefone`      VARCHAR(11)  NOT NULL,
    `arquivado`     TINYINT(1)   NOT NULL DEFAULT 0,
    `arquivado_em`  DATETIME     NULL,
    `criado_em`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `atualizado_em` TIMESTAMP    NULL ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_clientes_cpf`   (`cpf`),
    UNIQUE KEY `uk_clientes_cnh`   (`cnh`),
    UNIQUE KEY `uk_clientes_email` (`email`),

    CONSTRAINT `ck_clientes_nome`     CHECK (CHAR_LENGTH(TRIM(`nome`)) >= 3),
    CONSTRAINT `ck_clientes_cpf`      CHECK (`cpf` REGEXP '^[0-9]{11}$'),
    CONSTRAINT `ck_clientes_cnh`      CHECK (`cnh` REGEXP '^[0-9]{11}$'),
    CONSTRAINT `ck_clientes_email`    CHECK (`email` LIKE '_%@_%._%'),
    CONSTRAINT `ck_clientes_telefone` CHECK (`telefone` REGEXP '^[1-9][1-9][0-9]{8,9}$'),
    CONSTRAINT `ck_clientes_arquivado` CHECK (`arquivado` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------------------
-- VEÍCULOS
-- A placa é guardada sem hífen (ABC1234 ou ABC1D23), assim
-- "ABC-1234" e "ABC1234" contam como a mesma placa.
-- O status NÃO é escolhido à mão: muda sozinho com aluguéis e reparos.
-- ---------------------------------------------------------------------

CREATE TABLE `veiculos` (
    `id`            INT           NOT NULL AUTO_INCREMENT,
    `marca`         VARCHAR(100)  NOT NULL,
    `modelo`        VARCHAR(100)  NOT NULL,
    `ano`           SMALLINT      NOT NULL,
    `placa`         VARCHAR(7)    NOT NULL,
    `chassi`        CHAR(17)      NOT NULL,
    `valor_diaria`  DECIMAL(10,2) NOT NULL,
    `imagem`        VARCHAR(255)  NULL,
    `status`        ENUM('Disponível','Alugado','Em manutenção') NOT NULL DEFAULT 'Disponível',
    `arquivado`     TINYINT(1)    NOT NULL DEFAULT 0,
    `arquivado_em`  DATETIME      NULL,
    `criado_em`     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `atualizado_em` TIMESTAMP     NULL ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_veiculos_placa`  (`placa`),
    UNIQUE KEY `uk_veiculos_chassi` (`chassi`),
    KEY `idx_veiculos_status` (`status`, `arquivado`),

    CONSTRAINT `ck_veiculos_placa`
        CHECK (`placa` REGEXP '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'),
    CONSTRAINT `ck_veiculos_chassi`
        CHECK (`chassi` REGEXP '^[A-HJ-NPR-Z0-9]{17}$'),
    CONSTRAINT `ck_veiculos_ano`
        CHECK (`ano` BETWEEN 1950 AND 2100),
    CONSTRAINT `ck_veiculos_diaria`
        CHECK (`valor_diaria` > 0),
    CONSTRAINT `ck_veiculos_arquivado`
        CHECK (`arquivado` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------------------
-- LOCAÇÕES (ALUGUÉIS)
-- valor_diaria guarda o preço do dia do aluguel: se o preço do carro
-- mudar depois, o histórico não muda.
-- ---------------------------------------------------------------------

CREATE TABLE `locacoes` (
    `id`              INT           NOT NULL AUTO_INCREMENT,
    `cliente_id`      INT           NOT NULL,
    `veiculo_id`      INT           NOT NULL,
    `usuario_id`      INT           NULL,
    `data_retirada`   DATE          NOT NULL,
    `data_prevista`   DATE          NOT NULL,
    `data_devolucao`  DATE          NULL,
    `valor_diaria`    DECIMAL(10,2) NOT NULL,
    `dias_previstos`  INT           NOT NULL,
    `valor_previsto`  DECIMAL(10,2) NOT NULL,
    `dias_atraso`     INT           NOT NULL DEFAULT 0,
    `valor_atraso`    DECIMAL(10,2) NOT NULL DEFAULT 0,
    `valor_total`     DECIMAL(10,2) NOT NULL DEFAULT 0,
    `status`          ENUM('Em andamento','Finalizada','Cancelada') NOT NULL DEFAULT 'Em andamento',
    `observacoes`     TEXT          NULL,
    `finalizado_por`  INT           NULL,
    `finalizado_em`   DATETIME      NULL,
    `criado_em`       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_locacoes_status`  (`status`, `data_prevista`),
    KEY `idx_locacoes_devolucao` (`data_devolucao`),

    CONSTRAINT `fk_locacoes_cliente`
        FOREIGN KEY (`cliente_id`) REFERENCES `clientes` (`id`),
    CONSTRAINT `fk_locacoes_veiculo`
        FOREIGN KEY (`veiculo_id`) REFERENCES `veiculos` (`id`),
    CONSTRAINT `fk_locacoes_usuario`
        FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_locacoes_finalizado_por`
        FOREIGN KEY (`finalizado_por`) REFERENCES `usuarios` (`id`) ON DELETE SET NULL,

    CONSTRAINT `ck_locacoes_periodo`
        CHECK (`data_prevista` >= `data_retirada`),
    CONSTRAINT `ck_locacoes_devolucao`
        CHECK (`data_devolucao` IS NULL OR `data_devolucao` >= `data_retirada`),
    CONSTRAINT `ck_locacoes_valores`
        CHECK (`valor_diaria` > 0 AND `valor_previsto` >= 0
               AND `valor_atraso` >= 0 AND `valor_total` >= 0),
    CONSTRAINT `ck_locacoes_dias`
        CHECK (`dias_previstos` >= 1 AND `dias_atraso` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------------------
-- MANUTENÇÕES
-- Enquanto houver manutenção "Em andamento", o carro não pode ser alugado.
-- ---------------------------------------------------------------------

CREATE TABLE `manutencoes` (
    `id`                 INT           NOT NULL AUTO_INCREMENT,
    `veiculo_id`         INT           NOT NULL,
    `locacao_id`         INT           NULL,
    `defeito`            TEXT          NOT NULL,
    `oficina`            VARCHAR(150)  NULL,
    `data_entrada`       DATE          NOT NULL,
    `previsao_liberacao` DATE          NULL,
    `data_liberacao`     DATE          NULL,
    `servico_realizado`  TEXT          NULL,
    `custo`              DECIMAL(10,2) NULL,
    `status`             ENUM('Em andamento','Concluída') NOT NULL DEFAULT 'Em andamento',
    `usuario_id`         INT           NULL,
    `concluido_por`      INT           NULL,
    `criado_em`          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_manutencoes_status` (`status`),

    CONSTRAINT `fk_manutencoes_veiculo`
        FOREIGN KEY (`veiculo_id`) REFERENCES `veiculos` (`id`),
    CONSTRAINT `fk_manutencoes_locacao`
        FOREIGN KEY (`locacao_id`) REFERENCES `locacoes` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_manutencoes_usuario`
        FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_manutencoes_concluido_por`
        FOREIGN KEY (`concluido_por`) REFERENCES `usuarios` (`id`) ON DELETE SET NULL,

    CONSTRAINT `ck_manutencoes_custo`
        CHECK (`custo` IS NULL OR `custo` >= 0),
    CONSTRAINT `ck_manutencoes_liberacao`
        CHECK (`data_liberacao` IS NULL OR `data_liberacao` >= `data_entrada`),
    CONSTRAINT `ck_manutencoes_previsao`
        CHECK (`previsao_liberacao` IS NULL OR `previsao_liberacao` >= `data_entrada`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------------------
-- TENTATIVAS DE LOGIN (para bloquear ataques e mostrar ao chefe)
-- ---------------------------------------------------------------------

CREATE TABLE `login_tentativas` (
    `id`        INT          NOT NULL AUTO_INCREMENT,
    `email`     VARCHAR(150) NOT NULL,
    `ip`        VARCHAR(45)  NOT NULL,
    `sucesso`   TINYINT(1)   NOT NULL DEFAULT 0,
    `motivo`    VARCHAR(100) NULL,
    `criado_em` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_tentativas_email` (`email`, `criado_em`),
    KEY `idx_tentativas_ip`    (`ip`, `criado_em`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ---------------------------------------------------------------------
-- HISTÓRICO DE AÇÕES (quem fez o quê e quando)
-- ---------------------------------------------------------------------

CREATE TABLE `logs` (
    `id`          INT          NOT NULL AUTO_INCREMENT,
    `usuario_id`  INT          NULL,
    `modulo`      VARCHAR(30)  NOT NULL,
    `acao`        VARCHAR(50)  NOT NULL,
    `registro_id` INT          NULL,
    `descricao`   TEXT         NOT NULL,
    `ip`          VARCHAR(45)  NULL,
    `criado_em`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_logs_data`    (`criado_em`),
    KEY `idx_logs_usuario` (`usuario_id`),
    KEY `idx_logs_modulo`  (`modulo`),

    CONSTRAINT `fk_logs_usuario`
        FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- =====================================================================
-- DADOS DE EXEMPLO
-- =====================================================================

-- Usuários
-- Gabriel continua com a mesma senha que já usava.
-- Mariana, Lucas e Pedro usam a senha:  Royale@123

INSERT INTO `usuarios` (`id`, `nome`, `email`, `senha`, `cargo`, `ativo`, `trocar_senha`, `criado_em`) VALUES
(1, 'Gabriel S',     'gabriel@gmail.com',          '$2y$10$8Qr/oNo0oxJ5hFQC7TrAr.Ri0JDoL3cSdt.qADADmgL4WtJ1fjXJ2', 'chefe',       1, 0, DATE_SUB(NOW(), INTERVAL 240 DAY)),
(2, 'Mariana Costa', 'mariana@royalecars.com.br',  '$2y$10$.SvjeaymekhgiK.g12JU1.0a7s2lZ9Zn0Ylu6NbKdTYW1vIyJB1wq', 'gerente',     1, 0, DATE_SUB(NOW(), INTERVAL 210 DAY)),
(3, 'Lucas Pereira', 'lucas@royalecars.com.br',    '$2y$10$.SvjeaymekhgiK.g12JU1.0a7s2lZ9Zn0Ylu6NbKdTYW1vIyJB1wq', 'funcionario', 1, 0, DATE_SUB(NOW(), INTERVAL 180 DAY)),
(4, 'Pedro Alves',   'pedro@royalecars.com.br',    '$2y$10$.SvjeaymekhgiK.g12JU1.0a7s2lZ9Zn0Ylu6NbKdTYW1vIyJB1wq', 'funcionario', 0, 0, DATE_SUB(NOW(), INTERVAL 160 DAY));

INSERT INTO `usuario_permissoes` (`usuario_id`, `permissao`) VALUES
-- Gerente: tudo, menos o Painel Administrativo
(2, 'clientes_ver'), (2, 'clientes_gerenciar'), (2, 'clientes_arquivar'),
(2, 'veiculos_ver'), (2, 'veiculos_gerenciar'), (2, 'veiculos_arquivar'),
(2, 'locacoes_ver'), (2, 'locacoes_gerenciar'), (2, 'locacoes_cancelar'),
(2, 'manutencoes'),  (2, 'financeiro'),
(2, 'relatorios'),   (2, 'relatorios_financeiros'),
-- Funcionário: atendimento do balcão
(3, 'clientes_ver'), (3, 'clientes_gerenciar'),
(3, 'veiculos_ver'),
(3, 'locacoes_ver'), (3, 'locacoes_gerenciar'),
-- Funcionário desativado
(4, 'clientes_ver'), (4, 'veiculos_ver'), (4, 'locacoes_ver');


-- Clientes (CPF e CNH com dígitos verificadores válidos)

INSERT INTO `clientes` (`id`, `nome`, `cpf`, `cnh`, `cnh_validade`, `email`, `telefone`, `arquivado`, `arquivado_em`, `criado_em`) VALUES
(1, 'João da Silva',      '10433218100', '96001338941', DATE_ADD(CURDATE(), INTERVAL 900 DAY), 'joao@gmail.com',       '19999999999', 0, NULL, DATE_SUB(NOW(), INTERVAL 230 DAY)),
(2, 'Evaldo José',        '08386379499', '02654235141', DATE_ADD(CURDATE(), INTERVAL 600 DAY), 'evaldo@gmail.com',     '1940028922',  0, NULL, DATE_SUB(NOW(), INTERVAL 225 DAY)),
(3, 'Caio Andrade',       '16155940789', '81618495903', DATE_ADD(CURDATE(), INTERVAL 1200 DAY),'andrade@gmail.com',    '19989568439', 0, NULL, DATE_SUB(NOW(), INTERVAL 220 DAY)),
(4, 'Ana Beatriz Souza',  '31034131656', '47525534144', DATE_ADD(CURDATE(), INTERVAL 1500 DAY),'ana.souza@gmail.com',  '11987654321', 0, NULL, DATE_SUB(NOW(), INTERVAL 150 DAY)),
(5, 'Marcos Oliveira',    '92832764851', '35030564106', DATE_ADD(CURDATE(), INTERVAL 400 DAY), 'marcos.oli@hotmail.com','21998765432', 0, NULL, DATE_SUB(NOW(), INTERVAL 120 DAY)),
(6, 'Fernanda Lima',      '39537672409', '23884969629', DATE_ADD(CURDATE(), INTERVAL 800 DAY), 'fernanda.lima@gmail.com','19991234567', 0, NULL, DATE_SUB(NOW(), INTERVAL 90 DAY)),
(7, 'Rafael Mendes',      '53287101269', '26916697875', DATE_ADD(CURDATE(), INTERVAL 20 DAY),  'rafael.mendes@outlook.com','19993456789', 0, NULL, DATE_SUB(NOW(), INTERVAL 60 DAY)),
(8, 'Juliana Rocha',      '48018451427', '62704828170', DATE_SUB(CURDATE(), INTERVAL 15 DAY),  'juliana.rocha@gmail.com','11976543210', 1, DATE_SUB(NOW(), INTERVAL 10 DAY), DATE_SUB(NOW(), INTERVAL 200 DAY));


-- Veículos (placas antigas e Mercosul, todas sem hífen)

INSERT INTO `veiculos` (`id`, `marca`, `modelo`, `ano`, `placa`, `chassi`, `valor_diaria`, `status`, `arquivado`, `arquivado_em`, `criado_em`) VALUES
(1,  'Toyota',        'Corolla',        2025, 'FEG1A33', '9BRBDWHE5S0123451', 350.00,  'Disponível',    1, DATE_SUB(NOW(), INTERVAL 100 DAY), DATE_SUB(NOW(), INTERVAL 240 DAY)),
(2,  'BMW',           '320i',           2024, 'DEF2E34', 'WBA5R1C08RFS23456', 500.00,  'Disponível',    1, DATE_SUB(NOW(), INTERVAL 90 DAY),  DATE_SUB(NOW(), INTERVAL 240 DAY)),
(3,  'BMW',           'M3',             2026, 'ABC1D23', 'WBS43AY05TFR12345', 500.00,  'Disponível',    0, NULL, DATE_SUB(NOW(), INTERVAL 240 DAY)),
(4,  'Audi',          'A5 Sportback',   2024, 'AUD5E67', 'WAUZZZF54RA012345', 700.00,  'Disponível',    0, NULL, DATE_SUB(NOW(), INTERVAL 235 DAY)),
(7,  'Volkswagen',    'Jetta GLI',      2023, 'GTR3R35', '3VW5T7BU2PM012345', 450.00,  'Disponível',    0, NULL, DATE_SUB(NOW(), INTERVAL 230 DAY)),
(10, 'Porsche',       '911 Carrera',    2024, 'POR9A25', 'WP0AA2A93RS201234', 1800.00, 'Disponível',    0, NULL, DATE_SUB(NOW(), INTERVAL 225 DAY)),
(11, 'Mercedes-Benz', 'C63 AMG',        2026, 'MER6B24', 'W1KAF8HB4TR012345', 2500.00, 'Alugado',       0, NULL, DATE_SUB(NOW(), INTERVAL 220 DAY)),
(12, 'Toyota',        'Hilux SRX',      2023, 'HLX4521', '8AJBA3CD1P1654321', 380.00,  'Disponível',    0, NULL, DATE_SUB(NOW(), INTERVAL 180 DAY)),
(13, 'Jeep',          'Compass Limited',2024, 'JPC2F19', '988675139RKA12345', 320.00,  'Em manutenção', 0, NULL, DATE_SUB(NOW(), INTERVAL 170 DAY)),
(14, 'Honda',         'Civic Touring',  2022, 'CVC8834', '93HFC2630NZ123456', 280.00,  'Alugado',       0, NULL, DATE_SUB(NOW(), INTERVAL 160 DAY)),
(15, 'Land Rover',    'Range Rover Evoque', 2025, 'RRE7H40', 'SALZA2BX5SH123456', 1200.00, 'Alugado', 0, NULL, DATE_SUB(NOW(), INTERVAL 150 DAY));


-- Locações (finalizadas, canceladas e em andamento)

INSERT INTO `locacoes`
(`id`, `cliente_id`, `veiculo_id`, `usuario_id`, `data_retirada`, `data_prevista`, `data_devolucao`,
 `valor_diaria`, `dias_previstos`, `valor_previsto`, `dias_atraso`, `valor_atraso`, `valor_total`,
 `status`, `observacoes`, `finalizado_por`, `finalizado_em`, `criado_em`) VALUES

(1,  1, 3,  1, DATE_SUB(CURDATE(), INTERVAL 200 DAY), DATE_SUB(CURDATE(), INTERVAL 197 DAY), DATE_SUB(CURDATE(), INTERVAL 197 DAY),
     500.00, 3, 1500.00, 0, 0, 1500.00, 'Finalizada', NULL, 1, DATE_SUB(NOW(), INTERVAL 197 DAY), DATE_SUB(NOW(), INTERVAL 200 DAY)),

(2,  3, 7,  1, DATE_SUB(CURDATE(), INTERVAL 170 DAY), DATE_SUB(CURDATE(), INTERVAL 164 DAY), DATE_SUB(CURDATE(), INTERVAL 164 DAY),
     450.00, 6, 2700.00, 0, 0, 2700.00, 'Finalizada', NULL, 1, DATE_SUB(NOW(), INTERVAL 164 DAY), DATE_SUB(NOW(), INTERVAL 170 DAY)),

(3,  2, 10, 2, DATE_SUB(CURDATE(), INTERVAL 150 DAY), DATE_SUB(CURDATE(), INTERVAL 147 DAY), DATE_SUB(CURDATE(), INTERVAL 145 DAY),
     1800.00, 3, 5400.00, 2, 3600.00, 9000.00, 'Finalizada', 'Devolvido com 2 dias de atraso.', 2, DATE_SUB(NOW(), INTERVAL 145 DAY), DATE_SUB(NOW(), INTERVAL 150 DAY)),

(4,  4, 4,  3, DATE_SUB(CURDATE(), INTERVAL 120 DAY), DATE_SUB(CURDATE(), INTERVAL 115 DAY), DATE_SUB(CURDATE(), INTERVAL 115 DAY),
     700.00, 5, 3500.00, 0, 0, 3500.00, 'Finalizada', NULL, 3, DATE_SUB(NOW(), INTERVAL 115 DAY), DATE_SUB(NOW(), INTERVAL 120 DAY)),

(5,  5, 12, 3, DATE_SUB(CURDATE(), INTERVAL 95 DAY),  DATE_SUB(CURDATE(), INTERVAL 88 DAY),  DATE_SUB(CURDATE(), INTERVAL 88 DAY),
     380.00, 7, 2660.00, 0, 0, 2660.00, 'Finalizada', NULL, 3, DATE_SUB(NOW(), INTERVAL 88 DAY), DATE_SUB(NOW(), INTERVAL 95 DAY)),

(6,  6, 3,  2, DATE_SUB(CURDATE(), INTERVAL 70 DAY),  DATE_SUB(CURDATE(), INTERVAL 66 DAY),  DATE_SUB(CURDATE(), INTERVAL 66 DAY),
     500.00, 4, 2000.00, 0, 0, 2000.00, 'Finalizada', NULL, 2, DATE_SUB(NOW(), INTERVAL 66 DAY), DATE_SUB(NOW(), INTERVAL 70 DAY)),

(7,  1, 15, 3, DATE_SUB(CURDATE(), INTERVAL 50 DAY),  DATE_SUB(CURDATE(), INTERVAL 47 DAY),  DATE_SUB(CURDATE(), INTERVAL 47 DAY),
     1200.00, 3, 3600.00, 0, 0, 3600.00, 'Finalizada', NULL, 3, DATE_SUB(NOW(), INTERVAL 47 DAY), DATE_SUB(NOW(), INTERVAL 50 DAY)),

(8,  7, 7,  3, DATE_SUB(CURDATE(), INTERVAL 35 DAY),  DATE_SUB(CURDATE(), INTERVAL 30 DAY),  DATE_SUB(CURDATE(), INTERVAL 30 DAY),
     450.00, 5, 2250.00, 0, 0, 2250.00, 'Finalizada', NULL, 3, DATE_SUB(NOW(), INTERVAL 30 DAY), DATE_SUB(NOW(), INTERVAL 35 DAY)),

(9,  3, 13, 2, DATE_SUB(CURDATE(), INTERVAL 25 DAY),  DATE_SUB(CURDATE(), INTERVAL 20 DAY),  DATE_SUB(CURDATE(), INTERVAL 20 DAY),
     320.00, 5, 1600.00, 0, 0, 1600.00, 'Finalizada', 'Cliente relatou barulho na suspensão. Veículo enviado para a oficina.', 2, DATE_SUB(NOW(), INTERVAL 20 DAY), DATE_SUB(NOW(), INTERVAL 25 DAY)),

(10, 4, 10, 2, DATE_SUB(CURDATE(), INTERVAL 15 DAY),  DATE_SUB(CURDATE(), INTERVAL 13 DAY),  DATE_SUB(CURDATE(), INTERVAL 13 DAY),
     1800.00, 2, 3600.00, 0, 0, 3600.00, 'Finalizada', NULL, 2, DATE_SUB(NOW(), INTERVAL 13 DAY), DATE_SUB(NOW(), INTERVAL 15 DAY)),

(11, 5, 4,  3, DATE_SUB(CURDATE(), INTERVAL 10 DAY),  DATE_SUB(CURDATE(), INTERVAL 8 DAY),   NULL,
     700.00, 2, 1400.00, 0, 0, 0, 'Cancelada', 'Cliente desistiu antes da retirada.', 2, DATE_SUB(NOW(), INTERVAL 10 DAY), DATE_SUB(NOW(), INTERVAL 10 DAY)),

(12, 7, 12, 3, DATE_SUB(CURDATE(), INTERVAL 4 DAY),   DATE_SUB(CURDATE(), INTERVAL 1 DAY),   DATE_SUB(CURDATE(), INTERVAL 1 DAY),
     380.00, 3, 1140.00, 0, 0, 1140.00, 'Finalizada', NULL, 3, DATE_SUB(NOW(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 4 DAY)),

-- Em andamento (no prazo)
(13, 2, 11, 1, DATE_SUB(CURDATE(), INTERVAL 3 DAY),   DATE_ADD(CURDATE(), INTERVAL 5 DAY),   NULL,
     2500.00, 8, 20000.00, 0, 0, 20000.00, 'Em andamento', NULL, NULL, NULL, DATE_SUB(NOW(), INTERVAL 3 DAY)),

-- Em andamento (ATRASADA)
(14, 6, 14, 3, DATE_SUB(CURDATE(), INTERVAL 9 DAY),   DATE_SUB(CURDATE(), INTERVAL 2 DAY),   NULL,
     280.00, 7, 1960.00, 0, 0, 1960.00, 'Em andamento', NULL, NULL, NULL, DATE_SUB(NOW(), INTERVAL 9 DAY)),

-- Em andamento (devolução amanhã)
(15, 1, 15, 2, DATE_SUB(CURDATE(), INTERVAL 2 DAY),   DATE_ADD(CURDATE(), INTERVAL 1 DAY),   NULL,
     1200.00, 3, 3600.00, 0, 0, 3600.00, 'Em andamento', NULL, NULL, NULL, DATE_SUB(NOW(), INTERVAL 2 DAY));


-- Manutenções

INSERT INTO `manutencoes`
(`id`, `veiculo_id`, `locacao_id`, `defeito`, `oficina`, `data_entrada`, `previsao_liberacao`, `data_liberacao`,
 `servico_realizado`, `custo`, `status`, `usuario_id`, `concluido_por`, `criado_em`) VALUES

(1, 3,  NULL, 'Pastilhas de freio no limite de desgaste.', 'Auto Center Campinas',
    DATE_SUB(CURDATE(), INTERVAL 60 DAY), DATE_SUB(CURDATE(), INTERVAL 57 DAY), DATE_SUB(CURDATE(), INTERVAL 57 DAY),
    'Troca de pastilhas e discos de freio dianteiros.', 850.00, 'Concluída', 2, 2, DATE_SUB(NOW(), INTERVAL 60 DAY)),

(2, 12, NULL, 'Volante puxando para a direita.', 'Pneus & Cia',
    DATE_SUB(CURDATE(), INTERVAL 40 DAY), DATE_SUB(CURDATE(), INTERVAL 38 DAY), DATE_SUB(CURDATE(), INTERVAL 38 DAY),
    'Alinhamento, balanceamento e rodízio de pneus.', 420.00, 'Concluída', 3, 2, DATE_SUB(NOW(), INTERVAL 40 DAY)),

(3, 10, NULL, 'Revisão programada de 30.000 km.', 'Concessionária Porsche Center',
    DATE_SUB(CURDATE(), INTERVAL 12 DAY), DATE_SUB(CURDATE(), INTERVAL 10 DAY), DATE_SUB(CURDATE(), INTERVAL 10 DAY),
    'Troca de óleo, filtros e velas.', 2300.00, 'Concluída', 2, 2, DATE_SUB(NOW(), INTERVAL 12 DAY)),

(4, 13, 9,    'Ruído na suspensão dianteira relatado pelo cliente na devolução.', 'Auto Center Campinas',
    DATE_SUB(CURDATE(), INTERVAL 20 DAY), DATE_SUB(CURDATE(), INTERVAL 2 DAY), NULL,
    NULL, NULL, 'Em andamento', 2, NULL, DATE_SUB(NOW(), INTERVAL 20 DAY));


-- Histórico de ações (alguns exemplos)

INSERT INTO `logs` (`usuario_id`, `modulo`, `acao`, `registro_id`, `descricao`, `ip`, `criado_em`) VALUES
(1, 'usuarios',    'cadastrar',  2,  'Cadastrou o gerente Mariana Costa (mariana@royalecars.com.br).', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 210 DAY)),
(1, 'usuarios',    'cadastrar',  3,  'Cadastrou o funcionário Lucas Pereira (lucas@royalecars.com.br).', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 180 DAY)),
(1, 'usuarios',    'desativar',  4,  'Desativou o acesso de Pedro Alves.', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 30 DAY)),
(2, 'veiculos',    'editar',     10, 'Alterou o Porsche 911 Carrera (POR9A25): diária de R$ 1.600,00 para R$ 1.800,00.', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 140 DAY)),
(2, 'manutencoes', 'abrir',      4,  'Enviou o Jeep Compass Limited (JPC2F19) para manutenção: Ruído na suspensão dianteira.', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 20 DAY)),
(2, 'clientes',    'arquivar',   8,  'Arquivou o cliente Juliana Rocha (CPF 480.184.514-27).', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 10 DAY)),
(3, 'locacoes',    'cadastrar',  14, 'Registrou o aluguel #14: Honda Civic Touring (CVC8834) para Fernanda Lima.', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 9 DAY)),
(1, 'locacoes',    'cadastrar',  13, 'Registrou o aluguel #13: Mercedes-Benz C63 AMG (MER6B24) para Evaldo José.', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(2, 'locacoes',    'cadastrar',  15, 'Registrou o aluguel #15: Land Rover Range Rover Evoque (RRE7H40) para João da Silva.', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(3, 'locacoes',    'finalizar',  12, 'Registrou a devolução do aluguel #12: Toyota Hilux SRX (HLX4521). Total R$ 1.140,00.', '127.0.0.1', DATE_SUB(NOW(), INTERVAL 1 DAY));


-- Tentativas de login de exemplo (uma delas suspeita)

INSERT INTO `login_tentativas` (`email`, `ip`, `sucesso`, `motivo`, `criado_em`) VALUES
('pedro@royalecars.com.br', '192.168.0.37', 0, 'Usuário desativado', DATE_SUB(NOW(), INTERVAL 5 DAY)),
('admin@royalecars.com.br', '177.45.12.9',  0, 'E-mail não cadastrado', DATE_SUB(NOW(), INTERVAL 3 DAY)),
('gabriel@gmail.com',       '177.45.12.9',  0, 'Senha incorreta', DATE_SUB(NOW(), INTERVAL 3 DAY)),
('gabriel@gmail.com',       '177.45.12.9',  0, 'Senha incorreta', DATE_SUB(NOW(), INTERVAL 3 DAY)),
('lucas@royalecars.com.br', '127.0.0.1',    1, NULL, DATE_SUB(NOW(), INTERVAL 1 DAY));


-- Ajusta os contadores de ID
ALTER TABLE `usuarios`    AUTO_INCREMENT = 5;
ALTER TABLE `clientes`    AUTO_INCREMENT = 9;
ALTER TABLE `veiculos`    AUTO_INCREMENT = 16;
ALTER TABLE `locacoes`    AUTO_INCREMENT = 16;
ALTER TABLE `manutencoes` AUTO_INCREMENT = 5;
