<?php
function installBootstrap() {
    $commands = [
        'npm init -y',
        'npm install bootstrap @popperjs/core',
        'npm install --save-dev sass autoprefixer postcss'
    ];

    foreach ($commands as $cmd) {
        // Redireciona mensagens de erro (2>&1) para capturar no retorno do comando
        $output = shell_exec($cmd . ' 2>&1');
        echo "<pre>{$output}</pre>";
    }

    echo "<strong>Instalação concluída com sucesso!</strong>";
}

installBootstrap();
?>