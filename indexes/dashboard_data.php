<?php
/**
 * Arquivo: indexes/dashboard_data.php
 * Objetivo: API central (GET e POST) do GIE_DATA (Schema v2): áreas, espécies,
 *           plantios, sensores e irrigação. Responde sempre JSON.
 *
 * GET  ?acao=listar_areas      -> { areas: [...], catalogo: [...] }   (aba Áreas e Culturas)
 * GET  ?acao=resumo_dashboard  -> resumo da estufa                    (Dashboard / Estoque)
 *
 * POST (JSON) { "acao": ... }
 *   area            nome, umidade_min, umidade_max, ph_min, ph_max, [area_m2]
 *   planta          nome, agua, luz, ph_min, ph_max, nutricao        (só cadastra no catálogo)
 *   plantio         id_area, id_planta, qtd_plantada, [data_plantio] (planta uma espécie na área)
 *   remover_planta  id_area, id_planta   (tira a planta da área; a espécie continua no catálogo)
 *   remover_area    id_area                (apaga a área, seus plantios e sensores)
 *   remover_especie id_planta              (apaga do catálogo; só se não estiver plantada)
 *   toggle_irrigacao
 *   leitura_manual  temperatura, umidade_solo
 */

session_start();
require_once __DIR__ . '/conexao.php'; // disponibiliza $pdo

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');

const NIVEIS = ['baixa', 'media', 'alta'];
const LUZES  = ['sol_pleno', 'meia_sombra'];

function responder(int $codigo, string $status, string $mensagem, array $extra = []): void
{
    http_response_code($codigo);
    echo json_encode(
        array_merge(['status' => $status, 'mensagem' => $mensagem], $extra),
        JSON_UNESCAPED_UNICODE
    );
    exit;
}

function obterIdGardenPadrao(PDO $pdo): int
{
    $id = $pdo->query('SELECT id_garden FROM garden ORDER BY id_garden ASC LIMIT 1')->fetchColumn();
    if (!$id) {
        responder(404, 'erro', 'Nenhuma estufa encontrada. Execute o script 04_seed_demo.sql no banco.');
    }
    return (int) $id;
}

function obterIdUsuarioAtual(PDO $pdo): ?int
{
    if (!empty($_SESSION['id_usuario'])) {
        return (int) $_SESSION['id_usuario'];
    }
    $id = $pdo->query('SELECT id_usuario FROM usuario ORDER BY id_usuario ASC LIMIT 1')->fetchColumn();
    return $id ? (int) $id : null;
}

function dataValida(string $s): bool
{
    $d = DateTime::createFromFormat('Y-m-d', $s);
    return $d !== false && $d->format('Y-m-d') === $s;
}

// Sessão exigida tanto para GET quanto para POST.
if (!isset($_SESSION['id_usuario'])) {
    responder(401, 'erro', 'Sessão expirada. Faça login novamente.');
}

$metodo = $_SERVER['REQUEST_METHOD'];
if ($metodo !== 'GET' && $metodo !== 'POST') {
    responder(405, 'erro', 'Método não permitido. Use GET ou POST.');
}

// ============================================================================
// GET
// ============================================================================
if ($metodo === 'GET') {
    $acao = $_GET['acao'] ?? 'listar_areas';

    try {
        $idGarden = obterIdGardenPadrao($pdo);

        if ($acao === 'listar_areas') {
            $stmtAreas = $pdo->prepare(
                'SELECT id_area, area_nome, area_m2, umidade, umid_min_ideal, umid_max_ideal,
                        ph_solo, ph_min_ideal, ph_max_ideal
                   FROM vw_dash_area
                  WHERE fk_id_garden = :garden
                  ORDER BY id_area ASC'
            );
            $stmtAreas->execute([':garden' => $idGarden]);
            $listaAreas = $stmtAreas->fetchAll();

            $stmtPlantas = $pdo->prepare(
                'SELECT v.fk_id_area, v.fk_id_planta, v.planta_nome, v.necessidade_agua,
                        v.necessidade_luz, v.ph_ideal_min, v.ph_ideal_max, v.nutricao,
                        v.qtd_atual, ap.data_plantio
                   FROM vw_area_planta_detalhe v
                   LEFT JOIN area_planta ap
                          ON ap.fk_id_area = v.fk_id_area AND ap.fk_id_planta = v.fk_id_planta
                  WHERE v.fk_id_garden = :garden
                  ORDER BY v.planta_nome ASC'
            );
            $stmtPlantas->execute([':garden' => $idGarden]);

            $plantasPorArea = [];
            foreach ($stmtPlantas->fetchAll() as $p) {
                $plantasPorArea[(int) $p['fk_id_area']][] = [
                    'idPlanta' => (int) $p['fk_id_planta'],
                    'nome'     => $p['planta_nome'],
                    'agua'     => $p['necessidade_agua'],
                    'luz'      => $p['necessidade_luz'],
                    'phMin'    => (float) $p['ph_ideal_min'],
                    'phMax'    => (float) $p['ph_ideal_max'],
                    'nutricao' => $p['nutricao'],
                    'qtd'      => (int) $p['qtd_atual'],
                    'data'     => $p['data_plantio'],
                ];
            }

            $areas = [];
            foreach ($listaAreas as $a) {
                $id = (int) $a['id_area'];
                $areas[] = [
                    'id'         => $id,
                    'nome'       => $a['area_nome'],
                    'areaM2'     => $a['area_m2'] !== null ? (float) $a['area_m2'] : null,
                    'umidade'    => $a['umidade'] !== null ? (float) $a['umidade'] : null,
                    'umidadeMin' => (float) $a['umid_min_ideal'],
                    'umidadeMax' => (float) $a['umid_max_ideal'],
                    'ph'         => $a['ph_solo'] !== null ? (float) $a['ph_solo'] : null,
                    'phMin'      => (float) $a['ph_min_ideal'],
                    'phMax'      => (float) $a['ph_max_ideal'],
                    'plantas'    => $plantasPorArea[$id] ?? [],
                ];
            }

            $catalogo = [];
            $linhasCat = $pdo->query(
                'SELECT id_planta, nome_p, necessidade_agua, necessidade_luz,
                        ph_ideal_min, ph_ideal_max, nutricao
                   FROM plantas ORDER BY nome_p ASC'
            )->fetchAll();
            foreach ($linhasCat as $c) {
                $catalogo[] = [
                    'id'       => (int) $c['id_planta'],
                    'nome'     => $c['nome_p'],
                    'agua'     => $c['necessidade_agua'],
                    'luz'      => $c['necessidade_luz'],
                    'phMin'    => (float) $c['ph_ideal_min'],
                    'phMax'    => (float) $c['ph_ideal_max'],
                    'nutricao' => $c['nutricao'],
                ];
            }

            responder(200, 'sucesso', 'Dados carregados com sucesso.', ['areas' => $areas, 'catalogo' => $catalogo]);
        }

        if ($acao === 'resumo_dashboard') {
            $stmtResumo = $pdo->prepare('SELECT * FROM vw_dash_resumo WHERE id_garden = :g LIMIT 1');
            $stmtResumo->execute([':g' => $idGarden]);
            $resumo = $stmtResumo->fetch() ?: [];

            $stmtAreas = $pdo->prepare('SELECT area_nome, status_umidade, umidade, ph_solo FROM vw_dash_area WHERE fk_id_garden = :g');
            $stmtAreas->execute([':g' => $idGarden]);

            $areasFormatadas = [];
            $soma = 0.0;
            $cont = 0;
            foreach ($stmtAreas->fetchAll() as $ar) {
                $areasFormatadas[] = [
                    'nome'   => $ar['area_nome'],
                    'status' => strtoupper((string) $ar['status_umidade']),
                    'umidade' => $ar['umidade'] !== null ? (float) $ar['umidade'] : null,
                    'ph'      => $ar['ph_solo'] !== null ? (float) $ar['ph_solo'] : null,
                ];
                if ($ar['umidade'] !== null) {
                    $soma += (float) $ar['umidade'];
                    $cont++;
                }
            }

            $stmtTemp = $pdo->prepare("SELECT valor FROM vw_dash_sensor WHERE id_garden = :g AND tipo = 'ambiente' LIMIT 1");
            $stmtTemp->execute([':g' => $idGarden]);
            $temperatura = $stmtTemp->fetchColumn();

            $stmtInsumos = $pdo->prepare('SELECT nome_ins, estoque, unidade FROM vw_dash_insumo WHERE id_garden = :g ORDER BY id_insumo ASC');
            $stmtInsumos->execute([':g' => $idGarden]);
            $insumos = $stmtInsumos->fetchAll();

            $insumoTxt = fn(int $i): string =>
                isset($insumos[$i]) ? "{$insumos[$i]['estoque']} {$insumos[$i]['unidade']}" : '--';

            responder(200, 'sucesso', 'Resumo carregado.', [
                'areasAtivas' => (int) ($resumo['qtd_areas'] ?? count($areasFormatadas)),
                'areas'       => $areasFormatadas,
                'sensores'    => [
                    'temperatura' => ($temperatura !== false && $temperatura !== null) ? (float) $temperatura : '--',
                    'umidadeAr'   => 60, // sem sensor de umidade do ar no schema: valor fixo
                    'umidadeSolo' => $cont > 0 ? round($soma / $cont, 1) : 0,
                ],
                'irrigacao'   => [
                    'bombaLigada'      => !empty($resumo['irrigacao_ligada']),
                    'nivelAgua'        => (float) ($resumo['nivel_agua_pct'] ?? 0),
                    'proximaIrrigacao' => $resumo['ultima_irrigacao'] ?? 'Automática',
                ],
                'estoque'     => [
                    'fertilizante'   => $insumoTxt(0),
                    'substrato'      => $insumoTxt(1),
                    'sementesTomate' => $insumoTxt(2),
                ],
            ]);
        }

        responder(400, 'erro', 'Ação GET desconhecida.');
    } catch (PDOException $e) {
        error_log('Erro no GET dashboard_data.php: ' . $e->getMessage());
        responder(500, 'erro', 'Erro ao consultar o banco de dados.');
    }
}

// ============================================================================
// POST
// ============================================================================
$dados = json_decode(file_get_contents('php://input'), true);
if (!is_array($dados)) {
    responder(400, 'erro', 'Corpo da requisição inválido. Envie um JSON válido.');
}
$acao = $dados['acao'] ?? '';

try {
    $idGarden = obterIdGardenPadrao($pdo);

    // ---- Nova área (canteiro + sensores dedicados) --------------------------
    if ($acao === 'area') {
        $nome       = trim($dados['nome'] ?? '');
        $umidadeMin = isset($dados['umidade_min']) ? (float) $dados['umidade_min'] : 30.0;
        $umidadeMax = isset($dados['umidade_max']) ? (float) $dados['umidade_max'] : 70.0;
        $phMin      = isset($dados['ph_min']) ? (float) $dados['ph_min'] : 6.0;
        $phMax      = isset($dados['ph_max']) ? (float) $dados['ph_max'] : 7.0;
        $areaM2     = isset($dados['area_m2']) && (float) $dados['area_m2'] > 0 ? (float) $dados['area_m2'] : 10.0;

        if ($nome === '' || mb_strlen($nome) > 50) {
            responder(422, 'erro', 'O nome da área é obrigatório e deve ter até 50 caracteres.');
        }
        if ($umidadeMin < 0 || $umidadeMax > 100 || $umidadeMin >= $umidadeMax) {
            responder(422, 'erro', 'A umidade mínima deve ser menor que a máxima (entre 0% e 100%).');
        }
        if ($phMin < 0 || $phMax > 14 || $phMin >= $phMax) {
            responder(422, 'erro', 'O pH mínimo deve ser menor que o máximo (entre 0 e 14).');
        }

        $pdo->beginTransaction();

        $pdo->prepare("INSERT INTO sensor_controle (`local`, tipo) VALUES (:local, 'umidade')")
            ->execute([':local' => $nome]);
        $idSensorUmid = (int) $pdo->lastInsertId();
        $pdo->prepare('INSERT INTO sensor_umidade (id_sensor_controle, umid_min, umid_max) VALUES (:id, :min, :max)')
            ->execute([':id' => $idSensorUmid, ':min' => $umidadeMin, ':max' => $umidadeMax]);

        $pdo->prepare("INSERT INTO sensor_controle (`local`, tipo) VALUES (:local, 'ph_solo')")
            ->execute([':local' => $nome]);
        $idSensorPh = (int) $pdo->lastInsertId();
        $pdo->prepare('INSERT INTO sensor_ph_solo (id_sensor_controle, phs_min, phs_max) VALUES (:id, :min, :max)')
            ->execute([':id' => $idSensorPh, ':min' => $phMin, ':max' => $phMax]);

        $pdo->prepare(
            'INSERT INTO area (nome, area_m2, fk_id_garden, fk_id_sensor_umidade, fk_id_sensor_ph_solo)
             VALUES (:nome, :m2, :garden, :s_umid, :s_ph)'
        )->execute([
            ':nome' => $nome, ':m2' => $areaM2, ':garden' => $idGarden,
            ':s_umid' => $idSensorUmid, ':s_ph' => $idSensorPh,
        ]);
        $idArea = (int) $pdo->lastInsertId();

        $pdo->commit();
        responder(201, 'sucesso', 'Área criada com sucesso!', ['id' => $idArea]);
    }

    // ---- Nova espécie no catálogo (sem vincular a nenhuma área) -------------
    if ($acao === 'planta') {
        $nome     = trim($dados['nome'] ?? '');
        $agua     = $dados['agua'] ?? 'media';
        $luz      = $dados['luz'] ?? 'sol_pleno';
        $nutricao = $dados['nutricao'] ?? 'media';
        $phMin    = isset($dados['ph_min']) ? (float) $dados['ph_min'] : 6.0;
        $phMax    = isset($dados['ph_max']) ? (float) $dados['ph_max'] : 7.0;

        if ($nome === '' || mb_strlen($nome) > 100) {
            responder(422, 'erro', 'Informe o nome da planta (até 100 caracteres).');
        }
        if (!in_array($agua, NIVEIS, true) || !in_array($nutricao, NIVEIS, true) || !in_array($luz, LUZES, true)) {
            responder(422, 'erro', 'Valor inválido para água, luz ou nutrição.');
        }
        if ($phMin < 0 || $phMax > 14 || $phMin >= $phMax) {
            responder(422, 'erro', 'O pH mínimo deve ser menor que o pH máximo (entre 0 e 14).');
        }

        $stmt = $pdo->prepare('SELECT 1 FROM plantas WHERE nome_p = :nome LIMIT 1');
        $stmt->execute([':nome' => $nome]);
        if ($stmt->fetchColumn()) {
            responder(409, 'erro', 'Já existe uma espécie com esse nome no catálogo.');
        }

        $pdo->prepare(
            'INSERT INTO plantas (nome_p, necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao)
             VALUES (:nome, :agua, :luz, :ph_min, :ph_max, :nutricao)'
        )->execute([
            ':nome' => $nome, ':agua' => $agua, ':luz' => $luz,
            ':ph_min' => $phMin, ':ph_max' => $phMax, ':nutricao' => $nutricao,
        ]);

        responder(201, 'sucesso', 'Espécie cadastrada com sucesso!', ['id' => (int) $pdo->lastInsertId()]);
    }

    // ---- Plantar uma espécie do catálogo em uma área ------------------------
    if ($acao === 'plantio') {
        $idArea   = (int) ($dados['id_area'] ?? 0);
        $idPlanta = (int) ($dados['id_planta'] ?? 0);
        $qtd      = (int) ($dados['qtd_plantada'] ?? 0);
        $data     = trim((string) ($dados['data_plantio'] ?? ''));
        if ($data === '') {
            $data = date('Y-m-d');
        }

        if ($idArea <= 0 || $idPlanta <= 0) {
            responder(422, 'erro', 'Selecione a área e a espécie.');
        }
        if ($qtd < 1 || $qtd > 1000000) {
            responder(422, 'erro', 'Informe uma quantidade entre 1 e 1.000.000.');
        }
        if (!dataValida($data)) {
            responder(422, 'erro', 'Data do plantio inválida.');
        }

        $stmt = $pdo->prepare('SELECT 1 FROM area WHERE id_area = :id AND fk_id_garden = :g');
        $stmt->execute([':id' => $idArea, ':g' => $idGarden]);
        if (!$stmt->fetchColumn()) {
            responder(404, 'erro', 'Área não encontrada.');
        }
        $stmt = $pdo->prepare('SELECT 1 FROM plantas WHERE id_planta = :id');
        $stmt->execute([':id' => $idPlanta]);
        if (!$stmt->fetchColumn()) {
            responder(404, 'erro', 'Espécie não encontrada no catálogo.');
        }

        $pdo->beginTransaction();

        $stmt = $pdo->prepare('SELECT 1 FROM area_planta WHERE fk_id_area = :area AND fk_id_planta = :planta');
        $stmt->execute([':area' => $idArea, ':planta' => $idPlanta]);
        if ($stmt->fetchColumn()) {
            $pdo->rollBack();
            responder(409, 'erro', 'Esta planta já está cultivada nesta área.');
        }

        $pdo->prepare(
            'INSERT INTO area_planta (fk_id_area, fk_id_planta, qtd_plantada, data_plantio)
             VALUES (:area, :planta, :qtd, :data)'
        )->execute([':area' => $idArea, ':planta' => $idPlanta, ':qtd' => $qtd, ':data' => $data]);

        $stmt = $pdo->prepare("SELECT id_estagio FROM estagio_planta WHERE nome = 'broto' LIMIT 1");
        $stmt->execute();
        $idEstagio = (int) ($stmt->fetchColumn() ?: 1);

        $pdo->prepare(
            'INSERT INTO area_planta_estagio (fk_id_area, fk_id_planta, fk_id_estagio, quantidade)
             VALUES (:area, :planta, :estagio, :qtd)'
        )->execute([':area' => $idArea, ':planta' => $idPlanta, ':estagio' => $idEstagio, ':qtd' => $qtd]);

        $pdo->commit();
        responder(201, 'sucesso', 'Plantio registrado com sucesso!');
    }

    // ---- Remover planta da área --------------------------------------------
    if ($acao === 'remover_planta') {
        $idArea   = (int) ($dados['id_area'] ?? 0);
        $idPlanta = (int) ($dados['id_planta'] ?? 0);
        if ($idArea <= 0 || $idPlanta <= 0) {
            responder(422, 'erro', 'IDs de área e planta inválidos para remoção.');
        }

        $pdo->beginTransaction();
        $pdo->prepare('DELETE FROM area_planta_estagio WHERE fk_id_area = :area AND fk_id_planta = :planta')
            ->execute([':area' => $idArea, ':planta' => $idPlanta]);
        $del = $pdo->prepare('DELETE FROM area_planta WHERE fk_id_area = :area AND fk_id_planta = :planta');
        $del->execute([':area' => $idArea, ':planta' => $idPlanta]);
        $pdo->commit();

        if ($del->rowCount() === 0) {
            responder(404, 'erro', 'Planta não encontrada nesta área.');
        }
        responder(200, 'sucesso', 'Planta removida da área com sucesso.');
    }

    // ---- Remover área inteira (plantios, sensores dedicados e leituras) -----
    if ($acao === 'remover_area') {
        $idArea = (int) ($dados['id_area'] ?? 0);
        if ($idArea <= 0) {
            responder(422, 'erro', 'ID de área inválido.');
        }

        $stmt = $pdo->prepare(
            'SELECT fk_id_sensor_umidade, fk_id_sensor_ph_solo FROM area
              WHERE id_area = :id AND fk_id_garden = :g'
        );
        $stmt->execute([':id' => $idArea, ':g' => $idGarden]);
        $area = $stmt->fetch();
        if (!$area) {
            responder(404, 'erro', 'Área não encontrada.');
        }
        $sensores = array_values(array_filter([
            (int) $area['fk_id_sensor_umidade'],
            (int) $area['fk_id_sensor_ph_solo'],
        ]));

        $pdo->beginTransaction();

        $pdo->prepare('DELETE FROM area_planta_estagio WHERE fk_id_area = :id')->execute([':id' => $idArea]);
        $pdo->prepare('DELETE FROM area_planta WHERE fk_id_area = :id')->execute([':id' => $idArea]);
        $pdo->prepare('DELETE FROM area WHERE id_area = :id')->execute([':id' => $idArea]);

        // Os sensores eram exclusivos da área: removem-se leituras, subtipos e o sensor.
        foreach ($sensores as $idSensor) {
            $pdo->prepare('DELETE FROM leitura_sensor WHERE fk_id_sensor = :s')->execute([':s' => $idSensor]);
            $pdo->prepare('DELETE FROM sensor_umidade WHERE id_sensor_controle = :s')->execute([':s' => $idSensor]);
            $pdo->prepare('DELETE FROM sensor_ph_solo WHERE id_sensor_controle = :s')->execute([':s' => $idSensor]);
            $pdo->prepare('DELETE FROM sensor_controle WHERE id_sensor_controle = :s')->execute([':s' => $idSensor]);
        }

        $pdo->commit();
        responder(200, 'sucesso', 'Área removida com sucesso.');
    }

    // ---- Remover espécie do catálogo (só se não estiver plantada) -----------
    if ($acao === 'remover_especie') {
        $idPlanta = (int) ($dados['id_planta'] ?? 0);
        if ($idPlanta <= 0) {
            responder(422, 'erro', 'ID de espécie inválido.');
        }

        $stmt = $pdo->prepare('SELECT COUNT(*) FROM area_planta WHERE fk_id_planta = :p');
        $stmt->execute([':p' => $idPlanta]);
        if ((int) $stmt->fetchColumn() > 0) {
            responder(409, 'erro', 'Esta espécie ainda está plantada em alguma área. Remova-a das áreas primeiro.');
        }

        $del = $pdo->prepare('DELETE FROM plantas WHERE id_planta = :p');
        $del->execute([':p' => $idPlanta]);
        if ($del->rowCount() === 0) {
            responder(404, 'erro', 'Espécie não encontrada no catálogo.');
        }
        responder(200, 'sucesso', 'Espécie removida do catálogo.');
    }

    // ---- Ligar/desligar bomba ----------------------------------------------
    if ($acao === 'toggle_irrigacao') {
        $pdo->prepare(
            'UPDATE sistema_irrigacao si
               JOIN garden g ON g.fk_id_sist_irriga = si.id_sis_irr
                SET si.lig_bol = IF(si.lig_bol = 1, 0, 1)
              WHERE g.id_garden = :g'
        )->execute([':g' => $idGarden]);
        responder(200, 'sucesso', 'Status do sistema de irrigação atualizado.');
    }

    // ---- Leitura manual ----------------------------------------------------
    if ($acao === 'leitura_manual') {
        $temperatura = isset($dados['temperatura']) ? (float) $dados['temperatura'] : null;
        $umidadeSolo = isset($dados['umidade_solo']) ? (float) $dados['umidade_solo'] : null;
        $idUsuario   = obterIdUsuarioAtual($pdo);

        if ($temperatura === null || $umidadeSolo === null) {
            responder(422, 'erro', 'Informe os valores numéricos de Temperatura e Umidade do Solo.');
        }
        if ($umidadeSolo < 0 || $umidadeSolo > 100) {
            responder(422, 'erro', 'A umidade do solo deve estar entre 0 e 100%.');
        }

        $pdo->beginTransaction();
        $sqlLeitura = "INSERT INTO leitura_sensor (fk_id_sensor, valor, origem, fk_id_usuario)
                       VALUES (:sensor, :valor, 'manual', :usuario)";

        $stmt = $pdo->prepare('SELECT fk_id_sensor_ambiente FROM garden WHERE id_garden = :g LIMIT 1');
        $stmt->execute([':g' => $idGarden]);
        $idSensorAmb = (int) $stmt->fetchColumn();
        if ($idSensorAmb) {
            $pdo->prepare($sqlLeitura)->execute([':sensor' => $idSensorAmb, ':valor' => $temperatura, ':usuario' => $idUsuario]);
        }

        $stmt = $pdo->prepare('SELECT fk_id_sensor_umidade FROM area WHERE fk_id_garden = :g ORDER BY id_area ASC LIMIT 1');
        $stmt->execute([':g' => $idGarden]);
        $idSensorUmi = (int) $stmt->fetchColumn();
        if ($idSensorUmi) {
            $pdo->prepare($sqlLeitura)->execute([':sensor' => $idSensorUmi, ':valor' => $umidadeSolo, ':usuario' => $idUsuario]);
        }

        $pdo->commit();
        responder(201, 'sucesso', 'Leitura manual registrada com sucesso!');
    }

    responder(400, 'erro', 'Ação desconhecida.');

} catch (PDOException $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    $sqlState  = (string) $e->getCode();
    $mysqlCode = (int) ($e->errorInfo[1] ?? 0);
    $mysqlMsg  = $e->errorInfo[2] ?? 'Erro interno no banco de dados.';

    if ($sqlState === '45000' || $mysqlCode === 1644) { // mensagem das triggers
        responder(422, 'erro', $mysqlMsg);
    }
    if ($mysqlCode === 1062) {
        responder(409, 'erro', 'Já existe um registro com esse nome no banco de dados.');
    }
    if ($mysqlCode === 1451) {
        responder(409, 'erro', 'Não é possível remover: existem registros (perdas, leituras etc.) vinculados a este item.');
    }

    error_log('Erro no POST dashboard_data.php: ' . $e->getMessage());
    responder(500, 'erro', 'Erro ao gravar no banco de dados.');
}
