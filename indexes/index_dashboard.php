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
    <link rel="stylesheet" href="../src/style/dashboard.css">
</head>
<body>
    <aside class="lateral">
        <h2 class="logo">GIE</h2>
        <nav>
            <ul>
                <li><a href="index_dashboard.php" class="ativo" aria-current="page">Dashboard</a></li>
                <li><a href="index_areas.html">Áreas e Culturas</a></li>
                <li><a href="index_irrigacao.html">Irrigação &amp; Sensores</a></li>
                <li><a href="index_estoque.html">Estoque de Insumos</a></li>
                <li><a href="index_relatorios.html">Relatórios</a></li>
            </ul>
        </nav>
    </aside>

    <main>
        <header class="topo">
            <h1>Visão geral da estufa</h1>
            <div class="usuario">
                <span>Bem-vindo, Administrador</span>
                <form action="logout.php" method="POST">
                    <button type="submit" class="btn btn-contorno">Sair</button>
                </form>
            </div>
        </header>

        <div class="barra">
            <p id="atualizado-em">Carregando dados…</p>
            <div class="barra-acoes">
                <a href="index_irrigacao.html">Registrar leitura manual</a>
                <button type="button" class="btn btn-contorno" id="btn-atualizar">Atualizar</button>
            </div>
        </div>
        <p id="aviso" class="aviso" role="alert" hidden></p>

        <section class="indicadores" aria-label="Indicadores principais">
            <div>
                <span class="rotulo">Áreas ativas</span>
                <strong id="areas-ativas" data-numero>--</strong>
            </div>
            <div>
                <span class="rotulo">Temperatura</span>
                <strong id="temperatura">-- °C</strong>
            </div>
            <div>
                <span class="rotulo">Umidade do solo (média)</span>
                <strong id="umidade-solo">-- %</strong>
            </div>
            <div>
                <span class="rotulo">Umidade do ar</span>
                <strong id="umidade-ar">-- %</strong>
            </div>
        </section>

        <div class="colunas">
            <section class="painel">
                <div class="painel-topo">
                    <h3>Áreas</h3>
                    <a href="index_areas.html">Gerenciar plantas</a>
                </div>
                <div class="tabela-rolagem">
                    <table>
                        <thead>
                            <tr><th>Área</th><th>Umidade</th><th>pH</th><th>Situação</th></tr>
                        </thead>
                        <tbody id="lista-areas">
                            <tr><td colspan="4" class="vazio">Carregando…</td></tr>
                        </tbody>
                    </table>
                </div>
            </section>

            <div class="coluna-lateral">
                <section class="painel">
                    <h3>Irrigação</h3>
                    <dl>
                        <div><dt>Bomba</dt><dd><span id="status-bomba" class="situacao">--</span></dd></div>
                        <div><dt>Caixa d'água</dt><dd><strong id="nivel-agua">-- %</strong></dd></div>
                    </dl>
                    <progress id="barra-agua" max="100" value="0" aria-label="Nível da caixa d'água"></progress>
                    <p id="proxima-irrigacao" class="nota">Próxima irrigação: --</p>
                    <button type="button" class="btn" id="btn-irrigacao" data-dinamico>Ligar ou desligar bomba</button>
                </section>

                <section class="painel">
                    <div class="painel-topo">
                        <h3>Estoque de insumos</h3>
                        <a href="index_estoque.html">Gerenciar estoque</a>
                    </div>
                    <dl id="lista-estoque-resumo">
                        <div><dt>Carregando…</dt><dd>--</dd></div>
                    </dl>
                </section>
            </div>
        </div>
    </main>

    <script src="index_dashboard.js"></script>
</body>
</html>
