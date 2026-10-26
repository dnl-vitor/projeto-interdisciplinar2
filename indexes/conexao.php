<?php
// Este arquivo só cria a conexão ($pdo). Não imprime nada,
// para poder ser incluído por outros scripts (login, cadastro etc.).

$host     = getenv('DB_HOST') ?: '';
$db_name  = getenv('DB_NAME') ?: '';
$username = getenv('DB_USER') ?: '';
$password = getenv('DB_PASS') ?: '';
$port     = getenv('DB_PORT') ?: ;

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
    // Detalhes só no log do servidor, nunca na tela do usuário
    error_log('Falha na conexão com o banco: ' . $e->getMessage());
    http_response_code(500);
    exit('Erro ao conectar ao banco de dados.');
}
