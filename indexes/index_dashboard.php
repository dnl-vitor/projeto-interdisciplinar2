<?php
session_start();
header('Cache-Control: no-store, no-cache, must-revalidate');
if (!isset($_SESSION['id_usuario'])) {
    header('Location: index_cardlogin.html');
    exit;
}
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GIE - Visão Geral</title>
    <link rel="stylesheet" href="../src/style/style_dashboard.css">
</head>
<body>
    <aside class="sidebar">
        <div class="logo"><h2>GIE</h2></div>
        <nav class="menu">
            <ul>
                <li><a href="index_dashboard.php" class="active">Dashboard</a></li>
                <li><a href="index_areas.html">Áreas e Jardins</a></li>
                <li><a href="index_culturas.html">Culturas (Plantas)</a></li>
                <li><a href="index_irrigacao.html">Irrigação & Sensores</a></li>
                <li><a href="index_estoque.html">Estoque de Insumos</a></li>
                <li><a href="index_relatorios.html">Relatórios</a></li>
            </ul>
        </nav>
    </aside>

    <main class="main-content">
        <header class="top-header">
            <h1>Visão Geral da Estufa</h1>
            <div class="user-info" style="display:flex; align-items:center; gap:12px;">
                <span>Bem-vindo, Administrador</span>
                <form action="logout.php" method="POST" style="margin:0;">
                    <button type="submit" class="btn" style="width:auto; padding:6px 16px;">Sair</button>
                </form>
            </div>
        </header>

        <section class="dashboard-grid">
            <!-- Card: Plantas e Jardins -->
            <article class="card">
                <h3>Plantio e Áreas</h3>
                <p>Status: <strong id="areas-ativas">-- Áreas Ativas</strong></p>
                <ul id="lista-areas"><li>A carregar...</li></ul>
                <button class="btn">Gerenciar Plantas</button>
            </article>

            <!-- Card: Monitoramento Ambiental (Sensores) -->
            <article class="card">
                <h3>Sensores Atuais</h3>
                <div class="sensor-data">
                    <p>Temperatura: <span id="temperatura" class="highlight-green">-- °C</span></p>
                    <p>Umidade do Ar: <span id="umidade-ar" class="highlight-green">-- %</span></p>
                    <p>Umidade do Solo: <span id="umidade-solo" class="highlight-orange">-- %</span></p>
                </div>
                <button class="btn">Ver Histórico</button>
            </article>

            <!-- Card: Automação Hídrica -->
            <article class="card">
                <h3>Sistema de Irrigação</h3>
                <p>Status da Bomba: <span id="status-bomba" class="highlight-green">--</span></p>
                <p>Nível da Caixa D'água: <strong id="nivel-agua">-- %</strong></p>
                <p id="proxima-irrigacao">Próxima Irrigação: --</p>
                <button class="btn" id="btn-irrigacao">Controle Manual</button>
            </article>
        </section>
    </main>

    <script src="index_dashboard.js"></script>
</body>
</html>
