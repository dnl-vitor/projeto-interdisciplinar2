<?php
/**
 * Ficheiro: indexes/instalar_banco.example.php
 * Objetivo: Modelo do instalador automático do banco de dados GIE_DATA.
 *
 * COMO USAR:
 * 1. Faz uma cópia deste ficheiro na mesma pasta (indexes/) e renomeia para:
 *    instalar_banco.php
 * 2. Ajusta as variáveis $username e $password abaixo conforme o teu MySQL/XAMPP.
 * 3. Acede no navegador: http://localhost/nome-da-pasta/indexes/instalar_banco.php
 */

header('Content-Type: text/html; charset=utf-8');

// =========================================================================
// CONFIGURAÇÃO DE ACESSO AO MYSQL (Ajusta estes valores na tua cópia local)
// =========================================================================
$host     = getenv('DB_HOST') ?: '127.0.0.1';
$port     = getenv('DB_PORT') ?: '3306';
$username = getenv('DB_USER') ?: 'root'; // Utilizador do MySQL (ex: 'root')
$password = getenv('DB_PASS') !== false ? getenv('DB_PASS') : ''; // Senha do MySQL (ex: '' ou '123456')

// Caminho para a pasta onde estão os ficheiros .sql
$pastaSql = __DIR__ . '/../database';

echo "<body style='font-family: Segoe UI, Arial, sans-serif; background: #0b210b; color: #f0f5ef; padding: 30px; line-height: 1.6;'>";
echo "<h2>🛠️ Instalador Automático do Banco de Dados (GIE_DATA)</h2>";

try {
    // 1. Liga ao servidor MySQL/MariaDB
    $pdo = new PDO(
        "mysql:host={$host};port={$port};charset=utf8mb4",
        $username,
        $password,
        [
            PDO::ATTR_ERRMODE          => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_EMULATE_PREPARES => true
        ]
    );
    echo "<p style='color: #68bd5f;'>✔ Ligado ao MySQL com o utilizador <strong>" . htmlspecialchars($username) . "</strong> com sucesso!</p>";

    /**
     * Função auxiliar para ler, adaptar compatibilidades SQL e executar os comandos.
     */
    function executarArquivoSql(PDO $pdo, string $caminhoArquivo): void
    {
        if (!file_exists($caminhoArquivo)) {
            throw new Exception("Ficheiro não encontrado: {$caminhoArquivo}");
        }

        $sql = file_get_contents($caminhoArquivo);

        // Collation compatível com MariaDB e MySQL
        $sql = str_replace('utf8mb4_0900_ai_ci', 'utf8mb4_general_ci', $sql);

        // Garante compatibilidade com DEFAULT (CURRENT_DATE)
        $sql = preg_replace(
            '/DEFAULT\s*\(?\s*CURRENT_DATE(?:\(\))?\s*\)?/i',
            'DEFAULT (CURRENT_DATE)',
            $sql
        );

        // Fallback de JSON_OBJECTAGG para versões mais antigas do MariaDB
        $sql = str_replace(
            'JSON_OBJECTAGG(es.nome, ape.quantidade)',
            "CONCAT('{', GROUP_CONCAT(CONCAT('\"', es.nome, '\":', ape.quantidade)), '}')",
            $sql
        );

        // Simplifica o bloco de leituras históricas de 24h para evitar erros de CTE
        $sql = preg_replace(
            "/INSERT INTO leitura_sensor[\s\S]*?FROM n CROSS JOIN sens[\s\S]*?ORDER BY n\.i, sens\.id;/i",
            "-- Leituras históricas simplificadas para compatibilidade",
            $sql
        );

        // Remove comentários de linha (-- ...)
        $linhas = explode("\n", $sql);
        $linhasLimpas = [];
        foreach ($linhas as $linha) {
            if (!preg_match('/^\s*--/', $linha)) {
                $linhasLimpas[] = $linha;
            }
        }
        $sqlLimpo = implode("\n", $linhasLimpas);

        // Separa blocos delimitados por DELIMITER (triggers e procedures)
        $partes = preg_split('/^\s*DELIMITER\s+(\S+)\s*$/m', $sqlLimpo, -1, PREG_SPLIT_DELIM_CAPTURE);

        $delimitador = ';';
        for ($i = 0; $i < count($partes); $i++) {
            if ($i % 2 === 1) {
                $delimitador = $partes[$i];
                continue;
            }
            $bloco = trim($partes[$i]);
            if ($bloco === '') continue;

            $comandos = explode($delimitador, $bloco);
            foreach ($comandos as $cmd) {
                $cmd = trim($cmd);
                if ($cmd === '') continue;

                $stmt = $pdo->prepare($cmd);
                $stmt->execute();
                do {
                    $stmt->fetchAll();
                } while ($stmt->nextRowset());
            }
        }
    }

    // 2. Executa os ficheiros estruturais na ordem obrigatória
    $arquivos = [
        '01_schema.sql',
        '02_views.sql',
        '03_procedures.sql',
        '04_seed_demo.sql'
    ];

    foreach ($arquivos as $arq) {
        echo "<p>⏳ A executar <strong>{$arq}</strong>...</p>";
        executarArquivoSql($pdo, $pastaSql . '/' . $arq);
        echo "<p style='color: #68bd5f;'>✔ <strong>{$arq}</strong> instalado com sucesso!</p>";
    }

    echo "<hr style='border-color: rgba(255,255,255,0.2); margin: 20px 0;'>";
    echo "<h3 style='color: #68bd5f;'>🎉 Tudo pronto! O banco de dados GIE_DATA foi configurado com sucesso!</h3>";
    echo "<p><a href='index_areas.html' style='display:inline-block; padding: 12px 20px; background: #159b18; color: #fff; text-decoration: none; border-radius: 20px; font-weight: bold;'>👉 Abrir Áreas e Culturas</a></p>";

} catch (Exception $e) {
    echo "<h3 style='color: #ff6b6b;'>❌ Ocorreu um erro durante a instalação:</h3>";
    echo "<pre style='background: rgba(0,0,0,0.4); padding: 15px; border-radius: 8px; color: #ffbcbc; white-space: pre-wrap;'>" . htmlspecialchars($e->getMessage()) . "</pre>";
    echo "<p>💡 <strong>Dica:</strong> Verifica se o MySQL está ativo no XAMPP e se o utilizador/senha em <code>instalar_banco.php</code> estão corretos.</p>";
}
echo "</body>";