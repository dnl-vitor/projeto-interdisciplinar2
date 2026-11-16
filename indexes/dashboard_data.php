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
// 4) Encerrar um plantio (marca como colhido e guarda a data; o histórico fica)
//    { "acao": "encerrar_plantio", "id_plantio": 7 }
//
// Sucesso: { "status": "sucesso", "mensagem": "...", "id": 5 }
// Erro:    { "status": "erro", "mensagem": "..." }


/**
 * Arquivo: indexes/dashboard_data.php
 * Objetivo: API central (GET e POST) para gerenciar áreas, plantas, sensores e irrigação
 *           no banco de dados GIE_DATA (Schema v2).
 */

session_start();
require_once 'conexao.php'; // disponibiliza o objeto $pdo

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');

/**
 * Envia uma resposta JSON padronizada e encerra o script.
 */
function responder(int $codigo, string $status, string $mensagem, array $extra = []): void
{
    http_response_code($codigo);
    echo json_encode(
        array_merge(['status' => $status, 'mensagem' => $mensagem], $extra),
        JSON_UNESCAPED_UNICODE
    );
    exit;
}

/**
 * Busca o ID da estufa principal cadastrada na tabela `garden`.
 */
function obterIdGardenPadrao(PDO $pdo): int
{
    $stmt = $pdo->query('SELECT id_garden FROM garden ORDER BY id_garden ASC LIMIT 1');
    $id = $stmt->fetchColumn();
    if (!$id) {
        responder(404, 'erro', 'Nenhuma estufa encontrada. Execute o script 04_seed_demo.sql no banco.');
    }
    return (int) $id;
}

/**
 * Obtém o ID do usuário logado na sessão ou usa o primeiro usuário ativo para testes.
 */
function obterIdUsuarioAtual(PDO $pdo): ?int
{
    if (!empty($_SESSION['id_usuario'])) {
        return (int) $_SESSION['id_usuario'];
    }
    $stmt = $pdo->query('SELECT id_usuario FROM usuario ORDER BY id_usuario ASC LIMIT 1');
    $id = $stmt->fetchColumn();
    return $id ? (int) $id : null;
}

// ============================================================================
// 1. REQUISIÇÕES GET (Leitura de dados para Áreas e Dashboard)
// ============================================================================
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $acao = $_GET['acao'] ?? 'listar_areas';

    try {
        $idGarden = obterIdGardenPadrao($pdo);

        // 1.1 Lista todas as áreas e plantas cultivadas (usado por index_areas.js)
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
                'SELECT fk_id_area, fk_id_planta, planta_nome, necessidade_agua,
                        necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao, qtd_atual
                   FROM vw_area_planta_detalhe
                  WHERE fk_id_garden = :garden
                  ORDER BY planta_nome ASC'
            );
            $stmtPlantas->execute([':garden' => $idGarden]);
            $listaPlantas = $stmtPlantas->fetchAll();

            $areasFormatadas = [];
            foreach ($listaAreas as $a) {
                $nomeArea = $a['area_nome'];
                $areasFormatadas[$nomeArea] = [
                    'id_area'    => (int) $a['id_area'],
                    'umidade'    => $a['umidade'] !== null ? (float) $a['umidade'] : null,
                    'umidadeMin' => (float) $a['umid_min_ideal'],
                    'umidadeMax' => (float) $a['umid_max_ideal'],
                    'ph'         => $a['ph_solo'] !== null ? (float) $a['ph_solo'] : null,
                    'phMin'      => (float) $a['ph_min_ideal'],
                    'phMax'      => (float) $a['ph_max_ideal'],
                    'plantas'    => []
                ];
            }

            foreach ($listaPlantas as $p) {
                foreach ($areasFormatadas as $nomeArea => &$dadosArea) {
                    if ($dadosArea['id_area'] === (int) $p['fk_id_area']) {
                        $dadosArea['plantas'][] = [
                            'id_planta' => (int) $p['fk_id_planta'],
                            'nome'      => $p['planta_nome'],
                            'agua'      => $p['necessidade_agua'],
                            'luz'       => $p['necessidade_luz'],
                            'phMin'     => (float) $p['ph_ideal_min'],
                            'phMax'     => (float) $p['ph_ideal_max'],
                            'nutricao'  => $p['nutricao'],
                            'qtdAtual'  => (int) $p['qtd_atual']
                        ];
                    }
                }
                unset($dadosArea);
            }

            responder(200, 'sucesso', 'Dados carregados com sucesso.', ['areas' => $areasFormatadas]);
        }

        // 1.2 Resumo geral da estufa (usado por index_dashboard.js)
        if ($acao === 'resumo_dashboard') {
            $stmtResumo = $pdo->prepare('SELECT * FROM vw_dash_resumo WHERE id_garden = :g LIMIT 1');
            $stmtResumo->execute([':g' => $idGarden]);
            $resumo = $stmtResumo->fetch() ?: [];

            $stmtAreas = $pdo->prepare('SELECT area_nome, status_umidade, umidade FROM vw_dash_area WHERE fk_id_garden = :g');
            $stmtAreas->execute([':g' => $idGarden]);
            $areasDb = $stmtAreas->fetchAll();

            $areasFormatadas = [];
            $somaUmidadeSolo = 0.0;
            $contUmidadeSolo = 0;

            foreach ($areasDb as $ar) {
                $areasFormatadas[] = [
                    'nome'   => $ar['area_nome'],
                    'status' => strtoupper($ar['status_umidade'])
                ];
                if ($ar['umidade'] !== null) {
                    $somaUmidadeSolo += (float) $ar['umidade'];
                    $contUmidadeSolo++;
                }
            }

            $stmtTemp = $pdo->prepare("SELECT valor FROM vw_dash_sensor WHERE id_garden = :g AND tipo = 'ambiente' LIMIT 1");
            $stmtTemp->execute([':g' => $idGarden]);
            $temperatura = $stmtTemp->fetchColumn();

            $stmtInsumos = $pdo->prepare('SELECT nome_ins, estoque, unidade FROM vw_dash_insumo WHERE id_garden = :g ORDER BY id_insumo ASC');
            $stmtInsumos->execute([':g' => $idGarden]);
            $insumos = $stmtInsumos->fetchAll();

            $umidadeSoloMedia = $contUmidadeSolo > 0 ? round($somaUmidadeSolo / $contUmidadeSolo, 1) : 0;

            responder(200, 'sucesso', 'Resumo carregado.', [
                'areasAtivas' => (int) ($resumo['qtd_areas'] ?? count($areasFormatadas)),
                'areas'       => $areasFormatadas,
                'sensores'    => [
                    'temperatura' => ($temperatura !== false && $temperatura !== null) ? (float) $temperatura : '--',
                    'umidadeAr'   => 60,
                    'umidadeSolo' => $umidadeSoloMedia
                ],
                'irrigacao'   => [
                    'bombaLigada'      => !empty($resumo['irrigacao_ligada']),
                    'nivelAgua'        => (float) ($resumo['nivel_agua_pct'] ?? 0),
                    'proximaIrrigacao' => $resumo['ultima_irrigacao'] ?? 'Automática'
                ],
                'estoque'     => [
                    'fertilizante'   => isset($insumos[0]) ? "{$insumos[0]['estoque']} {$insumos[0]['unidade']}" : '--',
                    'substrato'      => isset($insumos[1]) ? "{$insumos[1]['estoque']} {$insumos[1]['unidade']}" : '--',
                    'sementesTomate' => isset($insumos[2]) ? "{$insumos[2]['estoque']} {$insumos[2]['unidade']}" : '--'
                ]
            ]);
        }

        responder(400, 'erro', 'Ação GET desconhecida.');
    } catch (PDOException $e) {
        error_log('Erro no GET dashboard_data.php: ' . $e->getMessage());
        responder(500, 'erro', 'Erro ao consultar o banco de dados.');
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

function encerrarPlantio(PDO $pdo, array $d): void
{
    $idPlantio = validarInteiro($d['id_plantio'] ?? null, 'plantio', 1, ID_MAX);

    // GREATEST evita data de colheita anterior à data do plantio (violaria o CHECK).
    $stmt = $pdo->prepare(
        "UPDATE plantios
            SET status = 'colhido', data_colheita = GREATEST(CURDATE(), data_plantio)
          WHERE id_plantio = :id AND status = 'ativo'"
    );
    $stmt->execute([':id' => $idPlantio]);

    if ($stmt->rowCount() === 0) {
        responder(404, 'erro', 'Plantio ativo não encontrado.');
    }

    responder(200, 'sucesso', 'Plantio encerrado.', ['id' => $idPlantio]);
}

// ---------- Entrada ----------

if (!isset($_SESSION['id_usuario'])) {
    responder(401, 'erro', 'Sessão expirada. Faça login novamente.');
}

// ============================================================================
// 2. REQUISIÇÕES POST (Gravação e Atualização no Banco)
// ============================================================================
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    responder(405, 'erro', 'Método não permitido. Use GET ou POST.');
}

$dados = json_decode(file_get_contents('php://input'), true);
if (!is_array($dados)) {
    responder(400, 'erro', 'Corpo da requisição inválido. Envie um JSON válido.');
}

$acao = $dados['acao'] ?? '';

try {
    $idGarden = obterIdGardenPadrao($pdo);

    // ------------------------------------------------------------------------
    // AÇÃO 1: CRIAR NOVA ÁREA (Canteiro + Sensores dedicados)
    // ------------------------------------------------------------------------
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

        // Cria sensor de umidade exclusivo para a área
        $stmtSensor = $pdo->prepare("INSERT INTO sensor_controle (`local`, tipo) VALUES (:local, 'umidade')");
        $stmtSensor->execute([':local' => $nome]);
        $idSensorUmid = (int) $pdo->lastInsertId();

        $stmtSubUmid = $pdo->prepare(
            'INSERT INTO sensor_umidade (id_sensor_controle, umid_min, umid_max) VALUES (:id, :min, :max)'
        );
        $stmtSubUmid->execute([':id' => $idSensorUmid, ':min' => $umidadeMin, ':max' => $umidadeMax]);

        // Cria sensor de pH do solo exclusivo para a área
        $stmtSensorPh = $pdo->prepare("INSERT INTO sensor_controle (`local`, tipo) VALUES (:local, 'ph_solo')");
        $stmtSensorPh->execute([':local' => $nome]);
        $idSensorPh = (int) $pdo->lastInsertId();

        $stmtSubPh = $pdo->prepare(
            'INSERT INTO sensor_ph_solo (id_sensor_controle, phs_min, phs_max) VALUES (:id, :min, :max)'
        );
        $stmtSubPh->execute([':id' => $idSensorPh, ':min' => $phMin, ':max' => $phMax]);

        // Insere a área vinculada aos sensores
        $stmtArea = $pdo->prepare(
            'INSERT INTO area (nome, area_m2, fk_id_garden, fk_id_sensor_umidade, fk_id_sensor_ph_solo)
             VALUES (:nome, :m2, :garden, :s_umid, :s_ph)'
        );
        $stmtArea->execute([
            ':nome'   => $nome,
            ':m2'     => $areaM2,
            ':garden' => $idGarden,
            ':s_umid' => $idSensorUmid,
            ':s_ph'   => $idSensorPh
        ]);
        $idArea = (int) $pdo->lastInsertId();

        $pdo->commit();
        responder(201, 'sucesso', 'Área criada com sucesso!', ['id_area' => $idArea]);
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
        case 'encerrar_plantio':
            encerrarPlantio($pdo, $dados);
            break;
        default:
            responder(400, 'erro', 'Ação desconhecida. Use "area", "planta", "plantio" ou "encerrar_plantio".');
    }

    // ------------------------------------------------------------------------
    // AÇÃO 2: ADICIONAR PLANTA E VINCULAR À ÁREA ATUAL
    // ------------------------------------------------------------------------
    if ($acao === 'planta') {
        $nomeArea = trim($dados['area_nome'] ?? '');
        $nome     = trim($dados['nome'] ?? '');
        $agua     = $dados['agua'] ?? 'media';
        $luz      = $dados['luz'] ?? 'sol_pleno';
        $nutricao = $dados['nutricao'] ?? 'media';
        $phMin    = isset($dados['ph_min']) ? (float) $dados['ph_min'] : 6.0;
        $phMax    = isset($dados['ph_max']) ? (float) $dados['ph_max'] : 7.0;
        $qtd      = isset($dados['qtd_plantada']) && (int) $dados['qtd_plantada'] > 0 ? (int) $dados['qtd_plantada'] : 10;

        // Adapta o valor 'sombra' do HTML para o ENUM('sol_pleno','meia_sombra') do banco
        if ($luz === 'sombra') {
            $luz = 'meia_sombra';
        }

        if ($nome === '' || $nomeArea === '') {
            responder(422, 'erro', 'Informe o nome da planta e a área selecionada.');
        }
        if ($phMin < 0 || $phMax > 14 || $phMin >= $phMax) {
            responder(422, 'erro', 'O pH mínimo deve ser menor que o pH máximo (entre 0 e 14).');
        }

        $stmtBuscaArea = $pdo->prepare('SELECT id_area FROM area WHERE fk_id_garden = :g AND nome = :nome LIMIT 1');
        $stmtBuscaArea->execute([':g' => $idGarden, ':nome' => $nomeArea]);
        $idArea = (int) $stmtBuscaArea->fetchColumn();

        if (!$idArea) {
            responder(404, 'erro', 'Área selecionada não foi encontrada no banco de dados.');
        }

        $pdo->beginTransaction();

        // CORREÇÃO: Se a planta já existir no catálogo, reutiliza seu ID sem sobrescrever outras áreas
        $stmtBuscaPlanta = $pdo->prepare('SELECT id_planta FROM plantas WHERE nome_p = :nome LIMIT 1');
        $stmtBuscaPlanta->execute([':nome' => $nome]);
        $idPlanta = (int) $stmtBuscaPlanta->fetchColumn();

        if (!$idPlanta) {
            $stmtInsPlanta = $pdo->prepare(
                'INSERT INTO plantas (nome_p, necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao)
                 VALUES (:nome, :agua, :luz, :ph_min, :ph_max, :nutricao)'
            );
            $stmtInsPlanta->execute([
                ':nome'     => $nome,
                ':agua'     => $agua,
                ':luz'      => $luz,
                ':ph_min'   => $phMin,
                ':ph_max'   => $phMax,
                ':nutricao' => $nutricao
            ]);
            $idPlanta = (int) $pdo->lastInsertId();
        }

        // Verifica se a espécie já está plantada na área selecionada
        $stmtExisteVinculo = $pdo->prepare(
            'SELECT 1 FROM area_planta WHERE fk_id_area = :area AND fk_id_planta = :planta'
        );
        $stmtExisteVinculo->execute([':area' => $idArea, ':planta' => $idPlanta]);

        if ($stmtExisteVinculo->fetchColumn()) {
            $pdo->rollBack();
            responder(409, 'erro', 'Esta planta já está cultivada nesta área.');
        }

        // Vincula a planta à área
        $stmtAreaPlanta = $pdo->prepare(
            'INSERT INTO area_planta (fk_id_area, fk_id_planta, qtd_plantada, data_plantio)
             VALUES (:area, :planta, :qtd, CURRENT_DATE)'
        );
        $stmtAreaPlanta->execute([
            ':area'   => $idArea,
            ':planta' => $idPlanta,
            ':qtd'    => $qtd
        ]);

        // Registra a quantidade inicial no estágio 'broto'
        $stmtEstagio = $pdo->prepare("SELECT id_estagio FROM estagio_planta WHERE nome = 'broto' LIMIT 1");
        $stmtEstagio->execute();
        $idEstagio = (int) ($stmtEstagio->fetchColumn() ?: 1);

        $stmtInsEstagio = $pdo->prepare(
            'INSERT INTO area_planta_estagio (fk_id_area, fk_id_planta, fk_id_estagio, quantidade)
             VALUES (:area, :planta, :estagio, :qtd)'
        );
        $stmtInsEstagio->execute([
            ':area'    => $idArea,
            ':planta'  => $idPlanta,
            ':estagio' => $idEstagio,
            ':qtd'     => $qtd
        ]);

        $pdo->commit();
        responder(201, 'sucesso', 'Planta salva e vinculada à área com sucesso!', ['id_planta' => $idPlanta]);
    }

    // ------------------------------------------------------------------------
    // AÇÃO 3: REMOVER PLANTA DA ÁREA
    // ------------------------------------------------------------------------
    if ($acao === 'remover_planta') {
        $idArea   = (int) ($dados['id_area'] ?? 0);
        $idPlanta = (int) ($dados['id_planta'] ?? 0);

        if ($idArea <= 0 || $idPlanta <= 0) {
            responder(422, 'erro', 'IDs de área e planta inválidos para remoção.');
        }

        $stmtDel = $pdo->prepare('DELETE FROM area_planta WHERE fk_id_area = :area AND fk_id_planta = :planta');
        $stmtDel->execute([':area' => $idArea, ':planta' => $idPlanta]);

        responder(200, 'sucesso', 'Planta removida da área com sucesso.');
    }

    // ------------------------------------------------------------------------
    // AÇÃO 4: ALTERNAR BOMBA DE IRRIGAÇÃO (Botão "Controle Manual" do Dashboard)
    // ------------------------------------------------------------------------
    if ($acao === 'toggle_irrigacao') {
        $stmtSist = $pdo->prepare(
            'UPDATE sistema_irrigacao si
               JOIN garden g ON g.fk_id_sist_irriga = si.id_sis_irr
                SET si.lig_bol = IF(si.lig_bol = 1, 0, 1)
              WHERE g.id_garden = :g'
        );
        $stmtSist->execute([':g' => $idGarden]);

        responder(200, 'sucesso', 'Status do sistema de irrigação atualizado.');
    }

    // ------------------------------------------------------------------------
    // AÇÃO 5: SALVAR LEITURA MANUAL (Aba "Irrigação & Sensores")
    // ------------------------------------------------------------------------
    if ($acao === 'leitura_manual') {
        $temperatura = isset($dados['temperatura']) ? (float) $dados['temperatura'] : null;
        $umidadeSolo = isset($dados['umidade_solo']) ? (float) $dados['umidade_solo'] : null;
        $idUsuario   = obterIdUsuarioAtual($pdo);

        if ($temperatura === null || $umidadeSolo === null) {
            responder(422, 'erro', 'Informe os valores numéricos de Temperatura e Umidade do Solo.');
        }

        $pdo->beginTransaction();

        // Insere leitura no sensor de ambiente da estufa
        $stmtAmb = $pdo->prepare('SELECT fk_id_sensor_ambiente FROM garden WHERE id_garden = :g LIMIT 1');
        $stmtAmb->execute([':g' => $idGarden]);
        $idSensorAmb = (int) $stmtAmb->fetchColumn();

        if ($idSensorAmb) {
            $stmtInsLeitura = $pdo->prepare(
                "INSERT INTO leitura_sensor (fk_id_sensor, valor, origem, fk_id_usuario)
                 VALUES (:sensor, :valor, 'manual', :usuario)"
            );
            $stmtInsLeitura->execute([
                ':sensor'  => $idSensorAmb,
                ':valor'   => $temperatura,
                ':usuario' => $idUsuario
            ]);
        }

        // Insere leitura no sensor de umidade do primeiro canteiro da estufa
        $stmtUmi = $pdo->prepare('SELECT fk_id_sensor_umidade FROM area WHERE fk_id_garden = :g ORDER BY id_area ASC LIMIT 1');
        $stmtUmi->execute([':g' => $idGarden]);
        $idSensorUmi = (int) $stmtUmi->fetchColumn();

        if ($idSensorUmi) {
            $stmtInsUmi = $pdo->prepare(
                "INSERT INTO leitura_sensor (fk_id_sensor, valor, origem, fk_id_usuario)
                 VALUES (:sensor, :valor, 'manual', :usuario)"
            );
            $stmtInsUmi->execute([
                ':sensor'  => $idSensorUmi,
                ':valor'   => $umidadeSolo,
                ':usuario' => $idUsuario
            ]);
        }

        $pdo->commit();
        responder(201, 'sucesso', 'Leitura manual registrada com sucesso!');
    }

    responder(400, 'erro', 'Ação desconhecida.');

} catch (PDOException $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    $sqlState  = $e->getCode();
    $mysqlCode = (int) ($e->errorInfo[1] ?? 0);
    $mysqlMsg  = $e->errorInfo[2] ?? 'Erro interno no banco de dados.';

    // CORREÇÃO: Captura mensagens enviadas pelas Triggers do 01_schema.sql (SQLSTATE 45000)
    if ($sqlState === '45000' || $mysqlCode === 1644) {
        responder(422, 'erro', $mysqlMsg);
    }
    // Violação de chave única (registro duplicado)
    if ($mysqlCode === 1062) {
        responder(409, 'erro', 'Já existe um registro com esse nome no banco de dados.');
    }
    // CORREÇÃO: Violação de FK ao tentar remover planta que possui histórico de perdas
    if ($mysqlCode === 1451) {
        responder(409, 'erro', 'Não é possível remover esta planta pois ela possui registros de perda vinculados.');
    }

    error_log('Erro no POST dashboard_data.php: ' . $e->getMessage());
    responder(500, 'erro', 'Erro ao gravar no banco de dados.');
}
