DROP DATABASE IF EXISTS clinica_veterinaria;
CREATE DATABASE clinica_veterinaria;
USE clinica_veterinaria;

CREATE TABLE grupos_usuarios (id_grupo INT NOT NULL, nome_grupo VARCHAR(50) NOT NULL, descricao VARCHAR(255), PRIMARY KEY (id_grupo));
INSERT INTO grupos_usuarios VALUES (1, 'Administrador', 'Acesso total'), (2, 'Operador', 'Acesso operacional');

CREATE TABLE usuarios (id_usuario VARCHAR(36) NOT NULL, nome VARCHAR(100) NOT NULL, email VARCHAR(100) NOT NULL UNIQUE, senha_hash VARCHAR(255) NOT NULL, id_grupo INT NOT NULL, data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id_usuario), FOREIGN KEY (id_grupo) REFERENCES grupos_usuarios(id_grupo));

CREATE TABLE pacientes (id_paciente VARCHAR(36) NOT NULL, nome_animal VARCHAR(100) NOT NULL, especie VARCHAR(50) NOT NULL, raca VARCHAR(50), idade_estimada INT NOT NULL, id_usuario_cadastro VARCHAR(36) NOT NULL, data_registro DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id_paciente), FOREIGN KEY (id_usuario_cadastro) REFERENCES usuarios(id_usuario));

CREATE TABLE logs_auditoria (id_log VARCHAR(36) NOT NULL, id_usuario VARCHAR(36) NOT NULL, tabela_afetada VARCHAR(50) NOT NULL, acao VARCHAR(20) NOT NULL, descricao TEXT NOT NULL, data_log DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id_log), FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario));

CREATE TABLE log_acoes (id_acao VARCHAR(36) NOT NULL, id_usuario VARCHAR(36) NOT NULL, acao_realizada VARCHAR(100) NOT NULL, data_acao DATETIME DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id_acao), FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario));

CREATE INDEX idx_log_acoes_data ON log_acoes(data_acao);

CREATE VIEW vw_relatorio_performance_usuarios AS SELECT u.id_usuario, u.nome AS nome_usuario, u.email AS email_usuario, g.nome_grupo AS perfil_acesso, la.acao_realizada, la.data_acao FROM usuarios u INNER JOIN grupos_usuarios g ON u.id_grupo = g.id_grupo INNER JOIN log_acoes la ON u.id_usuario = la.id_usuario;

CREATE VIEW vw_estatisticas_clinica AS SELECT p.especie AS entidade_especie, COUNT(p.id_paciente) AS quantidade_pacientes, AVG(p.idade_estimada) AS media_idade_especie, (SELECT COUNT(*) FROM usuarios) AS total_usuarios_sistema, (SELECT COUNT(*) FROM log_acoes) AS total_logs_gerados FROM pacientes p GROUP BY p.especie;

DELIMITER $$
CREATE FUNCTION fn_gerar_id_usuario() RETURNS VARCHAR(36) DETERMINISTIC BEGIN RETURN UUID(); END$$
CREATE FUNCTION fn_gerar_id_log() RETURNS VARCHAR(36) DETERMINISTIC BEGIN RETURN UUID(); END$$

CREATE PROCEDURE sp_cadastrar_usuario(IN p_nome VARCHAR(100), IN p_email VARCHAR(100), IN p_senha_plana VARCHAR(255), IN p_id_grupo INT)
BEGIN
    DECLARE v_id_novo VARCHAR(36); DECLARE v_email_existe INT;
    SELECT COUNT(*) INTO v_email_existe FROM usuarios WHERE email = p_email;
    IF v_email_existe > 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: E-mail já cadastrado.';
    ELSE IF LENGTH(p_senha_plana) < 6 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Senha curta.';
    ELSE SET v_id_novo = fn_gerar_id_usuario(); INSERT INTO usuarios (id_usuario, nome, email, senha_hash, id_grupo) VALUES (v_id_novo, p_nome, p_email, SHA2(p_senha_plana, 256), p_id_grupo);
    END IF; END IF;
END$$

CREATE PROCEDURE sp_salvar_paciente(IN p_id_paciente VARCHAR(36), IN p_nome_animal VARCHAR(100), IN p_especie VARCHAR(50), IN p_raca VARCHAR(50), IN p_idade_estimada INT, IN p_id_usuario VARCHAR(36))
BEGIN
    IF p_idade_estimada < 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Idade negativa.';
    ELSE IF p_id_paciente IS NULL OR p_id_paciente = '' OR NOT EXISTS (SELECT 1 FROM pacientes WHERE id_paciente = p_id_paciente) THEN INSERT INTO pacientes (id_paciente, nome_animal, especie, raca, idade_estimada, id_usuario_cadastro) VALUES (UUID(), p_nome_animal, p_especie, p_raca, p_idade_estimada, p_id_usuario);
    ELSE UPDATE pacientes SET nome_animal = p_nome_animal, especie = p_especie, raca = p_raca, idade_estimada = p_idade_estimada, id_usuario_cadastro = p_id_usuario WHERE id_paciente = p_id_paciente;
    END IF; END IF;
END$$

CREATE TRIGGER trg_auditoria_usuario AFTER UPDATE ON usuarios FOR EACH ROW BEGIN INSERT INTO logs_auditoria (id_log, id_usuario, tabela_afetada, acao, descricao) VALUES (fn_gerar_id_log(), NEW.id_usuario, 'usuarios', 'UPDATE', CONCAT('Dados do utilizador ', NEW.nome, ' foram alterados.')); END$$

CREATE TRIGGER tg_validar_paciente_antes_inserir BEFORE INSERT ON pacientes FOR EACH ROW BEGIN IF TRIM(NEW.nome_animal) = '' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro: Nome animal obrigatório.'; END IF; SET NEW.especie = UPPER(TRIM(NEW.especie)); END$$
DELIMITER ;

CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED BY 'SenhaF0rte_App2026';
ALTER USER 'app_user'@'localhost' IDENTIFIED BY 'SenhaF0rte_App2026';

GRANT SELECT, INSERT, UPDATE ON clinica_veterinaria.usuarios TO 'app_user'@'localhost';
GRANT SELECT ON clinica_veterinaria.grupos_usuarios TO 'app_user'@'localhost';
GRANT SELECT ON clinica_veterinaria.logs_auditoria TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON clinica_veterinaria.pacientes TO 'app_user'@'localhost';
GRANT INSERT, SELECT ON clinica_veterinaria.log_acoes TO 'app_user'@'localhost';
GRANT SELECT ON clinica_veterinaria.vw_estatisticas_clinica TO 'app_user'@'localhost';
GRANT SELECT ON clinica_veterinaria.vw_relatorio_performance_usuarios TO 'app_user'@'localhost';
GRANT EXECUTE ON PROCEDURE clinica_veterinaria.sp_cadastrar_usuario TO 'app_user'@'localhost';
GRANT EXECUTE ON PROCEDURE clinica_veterinaria.sp_salvar_paciente TO 'app_user'@'localhost';
FLUSH PRIVILEGES;

CALL sp_cadastrar_usuario('Admin Master', 'admin@sistema.com', 'admin123', 1);
INSERT INTO logs_auditoria (id_log, id_usuario, tabela_afetada, acao, descricao) VALUES (fn_gerar_id_log(), (SELECT id_usuario FROM usuarios LIMIT 1), 'sistema', 'TESTE', 'Módulo de auditoria ativado com sucesso!');