<?php
require_once 'conexao.php'; // cria $pdo

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: index_cadastro.html');
    exit;
}

$email     = trim($_POST['email'] ?? '');
$senha     = $_POST['senha'] ?? '';
$confirmar = $_POST['confirmar_senha'] ?? '';

if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 50
    || strlen($senha) < 6 || $senha !== $confirmar) {
    header('Location: index_cadastro.html?erro=falha');
    exit;
}

// Nunca guarde a senha pura
$hash = password_hash($senha, PASSWORD_DEFAULT);

try {
    $stmt = $pdo->prepare('INSERT INTO usuario (email, senha) VALUES (:email, :senha)');
    $stmt->execute([':email' => $email, ':senha' => $hash]);
    header('Location: index_cardlogin.html');
} catch (PDOException $e) {
    // SQLSTATE 23000 = violação de unicidade (email já existe)
    $erro = ($e->getCode() === '23000') ? 'existe' : 'falha';
    header('Location: index_cadastro.html?erro=' . $erro);
}
exit;
