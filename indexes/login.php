<?php
session_start();
require_once 'conexao.php'; // cria $pdo

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: index_cardlogin.html');
    exit;
}

$email = trim($_POST['email'] ?? '');
$senha = $_POST['senha'] ?? '';

$stmt = $pdo->prepare('SELECT id_usuario, email, senha FROM usuario WHERE email = :email LIMIT 1');
$stmt->execute([':email' => $email]);
$usuario = $stmt->fetch();

// password_verify compara a senha digitada com o hash salvo no banco
if ($usuario && password_verify($senha, $usuario['senha'])) {
    session_regenerate_id(true);
    $_SESSION['id_usuario'] = $usuario['id_usuario'];
    $_SESSION['email']      = $usuario['email'];

    // Troque pelo destino depois do login
    header('Location: index_dashboard.php');
    exit;
}

// Mesma mensagem para email inexistente e senha errada (não revela qual deles falhou)
header('Location: index_cardlogin.html?erro=1');
exit;
