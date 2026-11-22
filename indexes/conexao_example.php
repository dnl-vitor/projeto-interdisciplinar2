<?php
/**
 * Arquivo: indexes/conexao.example.php
 * Objetivo: Modelo de conexão com o banco de dados GIE_DATA.
 * Instrução: Copie este arquivo para "indexes/conexao.php" e ajuste
 *            o usuário e a senha caso o seu MySQL não use o padrão do XAMPP.
 */

$host     = getenv('DB_HOST') ?: '127.0.0.1';
$port     = getenv('DB_PORT') ?: '3306';
$db_name  = getenv('DB_NAME') ?: 'GIE_DATA';
$username = getenv('DB_USER') ?: 'root';
$password = getenv('DB_PASS') !== false ? getenv('DB_PASS') : '';

try {
    $pdo = new PDO(
        "mysql:host={$host};port={$port};dbname={$db_name};charset=utf8mb4",
        $username,
        $password,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]
    );
} catch (PDOException $e) {
    error_log('Falha na conexão com o banco: ' . $e->getMessage());
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'status'   => 'erro',
        'mensagem' => 'Erro ao conectar ao banco de dados. Verifique o arquivo indexes/conexao.php.'
    ], JSON_UNESCAPED_UNICODE);
    exit;
}
