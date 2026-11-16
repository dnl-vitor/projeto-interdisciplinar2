<?php
// Devolve, em JSON, tudo que a aba "Áreas e Culturas" precisa para carregar:
// as áreas (com seus plantios ativos) e o catálogo de plantas.
//
// GET listar_areas.php
// {
//   "status": "sucesso",
//   "areas": [ { "id", "nome", "areaM2", "umidade", "umidadeMin", "umidadeMax",
//                "ph", "phMin", "phMax", "plantas": [ { "idPlantio", "nome", "agua", "luz",
//                "phMin", "phMax", "nutricao", "qtd", "data" } ] } ],
//   "catalogo": [ { "id", "nome", "agua", "luz", "phMin", "phMax", "nutricao" } ]
// }
// "umidade" e "ph" (leitura atual) vêm null até existir uma tabela de leituras.

session_start();
require __DIR__ . '/conexao.php'; // cria $pdo

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function responder(int $codigo, array $corpo): void
{
    http_response_code($codigo);
    echo json_encode($corpo, JSON_UNESCAPED_UNICODE);
    exit;
}

if (!isset($_SESSION['id_usuario'])) {
    responder(401, ['status' => 'erro', 'mensagem' => 'Sessão expirada. Faça login novamente.']);
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    responder(405, ['status' => 'erro', 'mensagem' => 'Método não permitido. Use GET.']);
}

try {
    $linhasAreas = $pdo->query(
        'SELECT id_area, nome, area_m2, umidade_ideal_min, umidade_ideal_max,
                ph_ideal_min, ph_ideal_max
           FROM areas
          ORDER BY nome'
    )->fetchAll();

    $linhasPlantios = $pdo->query(
        "SELECT p.id_plantio, p.id_area, p.qtd_plantada, p.data_plantio,
                pl.nome, pl.necessidade_agua, pl.necessidade_luz,
                pl.ph_ideal_min, pl.ph_ideal_max, pl.nutricao
           FROM plantios p
           JOIN plantas pl ON pl.id_planta = p.id_planta
          WHERE p.status = 'ativo'
          ORDER BY p.id_plantio"
    )->fetchAll();

    $linhasCatalogo = $pdo->query(
        'SELECT id_planta, nome, necessidade_agua, necessidade_luz,
                ph_ideal_min, ph_ideal_max, nutricao
           FROM plantas
          ORDER BY nome'
    )->fetchAll();
} catch (PDOException $e) {
    error_log('Erro ao listar áreas: ' . $e->getMessage()); // detalhes só no log
    responder(500, ['status' => 'erro', 'mensagem' => 'Erro ao ler o banco de dados.']);
}

// Agrupa os plantios por área
$plantiosPorArea = [];
foreach ($linhasPlantios as $p) {
    $plantiosPorArea[(int) $p['id_area']][] = [
        'idPlantio' => (int) $p['id_plantio'],
        'nome'      => $p['nome'],
        'agua'      => $p['necessidade_agua'],
        'luz'       => $p['necessidade_luz'],
        'phMin'     => (float) $p['ph_ideal_min'],
        'phMax'     => (float) $p['ph_ideal_max'],
        'nutricao'  => $p['nutricao'],
        'qtd'       => (int) $p['qtd_plantada'],
        'data'      => $p['data_plantio'],
    ];
}

$areas = [];
foreach ($linhasAreas as $a) {
    $id = (int) $a['id_area'];
    $areas[] = [
        'id'         => $id,
        'nome'       => $a['nome'],
        'areaM2'     => $a['area_m2'] === null ? null : (float) $a['area_m2'],
        'umidade'    => null, // TODO: leitura atual do sensor de umidade
        'umidadeMin' => (int) $a['umidade_ideal_min'],
        'umidadeMax' => (int) $a['umidade_ideal_max'],
        'ph'         => null, // TODO: leitura atual do sensor de pH
        'phMin'      => (float) $a['ph_ideal_min'],
        'phMax'      => (float) $a['ph_ideal_max'],
        'plantas'    => $plantiosPorArea[$id] ?? [],
    ];
}

$catalogo = [];
foreach ($linhasCatalogo as $c) {
    $catalogo[] = [
        'id'       => (int) $c['id_planta'],
        'nome'     => $c['nome'],
        'agua'     => $c['necessidade_agua'],
        'luz'      => $c['necessidade_luz'],
        'phMin'    => (float) $c['ph_ideal_min'],
        'phMax'    => (float) $c['ph_ideal_max'],
        'nutricao' => $c['nutricao'],
    ];
}

responder(200, ['status' => 'sucesso', 'areas' => $areas, 'catalogo' => $catalogo]);
