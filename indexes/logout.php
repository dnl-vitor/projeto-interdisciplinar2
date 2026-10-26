<?php
session_start();

// Só aceita logout via POST (evita que um link externo deslogue o usuário)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $_SESSION = [];

    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
    }

    session_destroy();
}

header('Location: index_cardlogin.html');
exit;
