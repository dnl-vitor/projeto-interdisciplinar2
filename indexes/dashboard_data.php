<?php
// Registra áreas, plantas (catálogo) e plantios no banco.
// Recebe JSON via POST e responde JSON, no mesmo padrão do inserir_leitura_manual.php.
// Tabelas usadas: areas, plantas, plantios (ver gie_modelagem.sql).
//
// 1) Registrar uma área
//    { "acao": "area", "nome": "Canteiro B",
//      "umidade_min": 30, "umidade_max": 70, "ph_min": 6.0, "ph_max": 7.0,
//      "area_m2": 12.5, "id_estufa": 1,
//      "id_sensor_umidade": 3, "id_sensor_ph": 4 }
//    Opcionais: area_m2, id_estufa (padrão 1), id_sensor_umidade, id_sensor_ph.
//
// 2) Cadastrar uma espécie no catálogo
//    { "acao": "planta", "nome": "Tomate", "agua": "media", "luz": "sol_pleno",
//      "ph_min": 6.0, "ph_max": 7.0, "nutricao": "alta" }
//
// 3) Plantar uma espécie existente em uma área
//    { "acao": "plantio", "id_area": 1, "id_planta": 2,
//      "qtd_plantada": 12, "data_plantio": "2026-11-07" }
//    Opcional: data_plantio (padrão: hoje).
//
// Sucesso: { "status": "sucesso", "mensagem": "...", "id": 5 }
// Erro:    { "status": "erro", "mensagem": "..." }

session_start();
require_once 'conexao.php'; // cria $pdo

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

const ID_ESTUFA_PADRAO = 1;          // mesmo DEFAULT da coluna areas.id_estufa
const ID_MAX           = 4294967295; // limite do INT UNSIGNED

function responder(int $codigo, string $status, string $mensagem, array $extra = []): void
{
    http_response_code($codigo);
    echo json_encode(
        array_merge(['status' => $status, 'mensagem' => $mensagem], $extra),
        JSON_UNESCAPED_UNICODE
    );
    exit;
}

// ---------- Validações ----------

// Campo opcional: devolve null se não veio, veio vazio ou nulo.
function opcional(array $d, string $chave)
{
    if (!array_key_exists($chave, $d) || $d[$chave] === null || $d[$chave] === '') {
        return null;
    }
    return $d[$chave];
}

function validarTexto($valor, string $campo, int $max = 80): string
{
    $texto = is_string($valor) ? trim($valor) : '';
    if ($texto === '' || mb_strlen($texto) > $max) {
        responder(422, 'erro', "O campo {$campo} é obrigatório e deve ter até {$max} caracteres.");
    }
    return $texto;
}

function validarInteiro($valor, string $campo, int $min, int $max): int
{
    $n = filter_var($valor, FILTER_VALIDATE_INT, ['options' => ['min_range' => $min, 'max_range' => $max]]);
    if ($n === false) {
        responder(422, 'erro', "O campo {$campo} deve ser um número inteiro entre {$min} e {$max}.");
    }
    return $n;
}

function validarDecimal($valor, string $campo, float $min, float $max, int $casas = 1): float
{
    $n = filter_var($valor, FILTER_VALIDATE_FLOAT);
    if ($n === false || $n < $min || $n > $max) {
        responder(422, 'erro', "O campo {$campo} deve ser um número entre {$min} e {$max}.");
    }
    return round($n, $casas);
}

function validarOpcao($valor, string $campo, array $permitidos): string
{
    if (!is_string($valor) || !in_array($valor, $permitidos, true)) {
        responder(422, 'erro', "Valor inválido para {$campo}.");
    }
    return $valor;
}

function validarData($valor, string $campo): string
{
    $data = is_string($valor) ? DateTime::createFromFormat('Y-m-d', $valor) : false;
    if (!$data || $data->format('Y-m-d') !== $valor) {
        responder(422, 'erro', "O campo {$campo} deve ser uma data válida no formato AAAA-MM-DD.");
    }
    return $valor;
}

// ---------- Banco ----------

// Sem foreign keys, o banco não confere se o id existe: a conferência é feita aqui.
// $tabela e $coluna são sempre constantes do código, nunca dados do usuário.
function existeRegistro(PDO $pdo, string $tabela, string $coluna, int $id): bool
{
    $stmt = $pdo->prepare("SELECT 1 FROM {$tabela} WHERE {$coluna} = :id");
    $stmt->execute([':id' => $id]);
    return (bool) $stmt->fetchColumn();
}

function erroDuplicado(PDOException $e): bool
{
    return (int) ($e->errorInfo[1] ?? 0) === 1062; // violação de UNIQUE
}

function mensagemDoBanco(PDOException $e): string
{
    return (string) ($e->errorInfo[2] ?? '');
}

// ---------- Operações ----------

function registrarArea(PDO $pdo, array $d): void
{
    $nome       = validarTexto($d['nome'] ?? null, 'nome');
    $umidadeMin = validarInteiro($d['umidade_min'] ?? null, 'umidade mínima', 0, 100);
    $umidadeMax = validarInteiro($d['umidade_max'] ?? null, 'umidade máxima', 0, 100);
    $phMin      = validarDecimal($d['ph_min'] ?? null, 'pH mínimo', 0, 14);
    $phMax      = validarDecimal($d['ph_max'] ?? null, 'pH máximo', 0, 14);

    if ($umidadeMin > $umidadeMax || $phMin > $phMax) {
        responder(422, 'erro', 'Os valores mínimos não podem ser maiores que os máximos.');
    }

    $v = opcional($d, 'id_estufa');
    $idEstufa = $v === null ? ID_ESTUFA_PADRAO : validarInteiro($v, 'estufa', 1, ID_MAX);

    $v = opcional($d, 'area_m2');
    $areaM2 = $v === null ? null : validarDecimal($v, 'área em m²', 0.01, 999999.99, 2);

    $v = opcional($d, 'id_sensor_umidade');
    $sensorUmidade = $v === null ? null : validarInteiro($v, 'sensor de umidade', 1, ID_MAX);

    $v = opcional($d, 'id_sensor_ph');
    $sensorPh = $v === null ? null : validarInteiro($v, 'sensor de pH', 1, ID_MAX);

    try {
        $stmt = $pdo->prepare(
            'INSERT INTO areas
                (id_estufa, nome, area_m2, umidade_ideal_min, umidade_ideal_max,
                 ph_ideal_min, ph_ideal_max, id_sensor_umidade, id_sensor_ph)
             VALUES
                (:id_estufa, :nome, :area_m2, :umi_min, :umi_max,
                 :ph_min, :ph_max, :sensor_umi, :sensor_ph)'
        );
        $stmt->execute([
            ':id_estufa'  => $idEstufa,
            ':nome'       => $nome,
            ':area_m2'    => $areaM2,
            ':umi_min'    => $umidadeMin,
            ':umi_max'    => $umidadeMax,
            ':ph_min'     => $phMin,
            ':ph_max'     => $phMax,
            ':sensor_umi' => $sensorUmidade,
            ':sensor_ph'  => $sensorPh,
        ]);
    } catch (PDOException $e) {
        if (erroDuplicado($e)) {
            if (strpos(mensagemDoBanco($e), 'uq_areas_sensor') !== false) {
                responder(409, 'erro', 'Esse sensor já está ligado a outra área.');
            }
            responder(409, 'erro', 'Já existe uma área com esse nome nesta estufa.');
        }
        throw $e;
    }

    responder(201, 'sucesso', 'Área registrada com sucesso.', ['id' => (int) $pdo->lastInsertId()]);
}

function registrarPlanta(PDO $pdo, array $d): void
{
    $nome     = validarTexto($d['nome'] ?? null, 'nome', 100);
    $agua     = validarOpcao($d['agua'] ?? null, 'água', ['baixa', 'media', 'alta']);
    $luz      = validarOpcao($d['luz'] ?? null, 'luz', ['sol_pleno', 'meia_sombra', 'sombra']);
    $nutricao = validarOpcao($d['nutricao'] ?? null, 'nutrição', ['baixa', 'media', 'alta']);
    $phMin    = validarDecimal($d['ph_min'] ?? null, 'pH mínimo', 0, 14);
    $phMax    = validarDecimal($d['ph_max'] ?? null, 'pH máximo', 0, 14);

    if ($phMin > $phMax) {
        responder(422, 'erro', 'O pH mínimo não pode ser maior que o pH máximo.');
    }

    try {
        $stmt = $pdo->prepare(
            'INSERT INTO plantas
                (nome, necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao)
             VALUES
                (:nome, :agua, :luz, :ph_min, :ph_max, :nutricao)'
        );
        $stmt->execute([
            ':nome'     => $nome,
            ':agua'     => $agua,
            ':luz'      => $luz,
            ':ph_min'   => $phMin,
            ':ph_max'   => $phMax,
            ':nutricao' => $nutricao,
        ]);
    } catch (PDOException $e) {
        if (erroDuplicado($e)) {
            responder(409, 'erro', 'Já existe uma planta com esse nome no catálogo.');
        }
        throw $e;
    }

    responder(201, 'sucesso', 'Planta cadastrada com sucesso.', ['id' => (int) $pdo->lastInsertId()]);
}

function registrarPlantio(PDO $pdo, array $d): void
{
    $idArea      = validarInteiro($d['id_area'] ?? null, 'área', 1, ID_MAX);
    $idPlanta    = validarInteiro($d['id_planta'] ?? null, 'planta', 1, ID_MAX);
    $qtdPlantada = validarInteiro($d['qtd_plantada'] ?? null, 'quantidade plantada', 1, 1000000);

    $v = opcional($d, 'data_plantio');
    $dataPlantio = $v === null ? date('Y-m-d') : validarData($v, 'data do plantio');

    if (!existeRegistro($pdo, 'areas', 'id_area', $idArea)) {
        responder(404, 'erro', 'Área não encontrada.');
    }
    if (!existeRegistro($pdo, 'plantas', 'id_planta', $idPlanta)) {
        responder(404, 'erro', 'Planta não encontrada no catálogo.');
    }

    $stmt = $pdo->prepare(
        'INSERT INTO plantios (id_area, id_planta, qtd_plantada, data_plantio)
         VALUES (:id_area, :id_planta, :qtd, :data)'
    );
    $stmt->execute([
        ':id_area'   => $idArea,
        ':id_planta' => $idPlanta,
        ':qtd'       => $qtdPlantada,
        ':data'      => $dataPlantio,
    ]);

    responder(201, 'sucesso', 'Plantio registrado com sucesso.', ['id' => (int) $pdo->lastInsertId()]);
}

// ---------- Entrada ----------

if (!isset($_SESSION['id_usuario'])) {
    responder(401, 'erro', 'Sessão expirada. Faça login novamente.');
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    responder(405, 'erro', 'Método não permitido. Use POST.');
}

$dados = json_decode(file_get_contents('php://input'), true);
if (!is_array($dados)) {
    responder(400, 'erro', 'Corpo da requisição inválido. Envie um JSON.');
}

try {
    switch ($dados['acao'] ?? '') {
        case 'area':
            registrarArea($pdo, $dados);
            break;
        case 'planta':
            registrarPlanta($pdo, $dados);
            break;
        case 'plantio':
            registrarPlantio($pdo, $dados);
            break;
        default:
            responder(400, 'erro', 'Ação desconhecida. Use "area", "planta" ou "plantio".');
    }
} catch (PDOException $e) {
    error_log('Erro ao registrar dados: ' . $e->getMessage()); // detalhes só no log
    responder(500, 'erro', 'Erro ao gravar no banco de dados.');
}
