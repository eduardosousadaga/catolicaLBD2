const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// Configuração do Banco de Dados
const dbConfig = {
    host: 'localhost',
    user: 'app_user',
    password: 'SenhaF0rte_App2026',
    database: 'clinica_veterinaria'
};

async function registrarAcao(id_usuario, acao_realizada) {
    try {
        const conn = await mysql.createConnection(dbConfig);
        await conn.query('INSERT INTO log_acoes (id_acao, id_usuario, acao_realizada) VALUES (UUID(), ?, ?)', [id_usuario, acao_realizada]);
        await conn.end();
    } catch (e) {
        console.error("Erro ao registar log de ação: ", e);
    }
}
app.post('/api/auth/register', async (req, res) => {
    const { nome, email, senha, id_grupo } = req.body;
    try {
        const connection = await mysql.createConnection(dbConfig);
        await connection.query('CALL sp_cadastrar_usuario(?, ?, ?, ?)', [nome, email, senha, id_grupo]);
        await connection.end();
        res.status(201).json({ message: 'Usuário cadastrado com sucesso!' });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

app.post('/api/auth/login', async (req, res) => {
    const { email, senha } = req.body;
    try {
        const connection = await mysql.createConnection(dbConfig);
        const [rows] = await connection.query(
            'SELECT id_usuario, nome, id_grupo FROM usuarios WHERE email = ? AND senha_hash = SHA2(?, 256)', 
            [email, senha]
        );
        await connection.end();

        if (rows.length > 0) {
            await registrarAcao(rows[0].id_usuario, 'Login no sistema');
            res.status(200).json({ message: 'Login bem-sucedido!', user: rows[0] });
        } else {
            res.status(401).json({ error: 'E-mail ou senha incorretos.' });
        }
    } catch (error) {
        res.status(500).json({ error: 'Erro interno no servidor.' });
    }
});

app.post('/api/pacientes/salvar', async (req, res) => {
    const { id_paciente, nome_animal, especie, raca, idade_estimada, id_usuario } = req.body;
    try {
        const connection = await mysql.createConnection(dbConfig);
        await connection.query('CALL sp_salvar_paciente(?, ?, ?, ?, ?, ?)', 
            [id_paciente || null, nome_animal, especie, raca, idade_estimada, id_usuario]
        );
        await connection.end();
        await registrarAcao(id_usuario, `Salvou paciente: ${nome_animal}`);
        res.status(200).json({ message: 'Dados operacionais salvos!' });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

app.get('/api/logs', async (req, res) => {
    try {
        const connection = await mysql.createConnection(dbConfig);
        const [rows] = await connection.query(`
            SELECT l.id_log, u.nome, l.tabela_afetada, l.acao, l.descricao, l.data_log
            FROM logs_auditoria l INNER JOIN usuarios u ON l.id_usuario = u.id_usuario
            ORDER BY l.data_log DESC
        `);
        await connection.end();
        res.status(200).json(rows);
    } catch (error) {
        res.status(500).json({ error: 'Erro interno ao consultar os logs.' });
    }
});

app.get('/api/relatorios/performance', async (req, res) => {
    try {
        const connection = await mysql.createConnection(dbConfig);
        const [rows] = await connection.query('SELECT * FROM vw_relatorio_performance_usuarios ORDER BY data_acao DESC');
        await connection.end();
        res.status(200).json(rows);
    } catch (error) {
        res.status(500).json({ error: 'Erro ao gerar relatório.' });
    }
});

app.listen(3000, () => console.log('Servidor rodando na porta 3000'));