<?php
/**
 * Arquivo: indexes/dashboard_data.php
 * Objetivo: API central (GET e POST) para gerenciar áreas, espécies/plantios,
 *           sensores, irrigação, estoque de insumos, históricos e relatórios
 *           no banco GIE_DATA.
 */

session_start();
require_once 'conexao.php'; // disponibiliza o objeto $pdo

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');

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
    $stmt = $pdo->query('SELECT id_garden FROM garden ORDER BY id_garden ASC LIMIT 1');
    $id = $stmt->fetchColumn();
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
    $stmt = $pdo->query('SELECT id_usuario FROM usuario ORDER BY id_usuario ASC LIMIT 1');
    $id = $stmt->fetchColumn();
    return $id ? (int) $id : null;
}

// ============================================================================
// 1. REQUISIÇÕES GET (Leitura de dados)
// ============================================================================
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $acao = $_GET['acao'] ?? 'listar_areas';

    try {
        $idGarden = obterIdGardenPadrao($pdo);

        // 1.1 Lista todas as áreas (array), plantas cultivadas e catálogo de espécies
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
                        necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao,
                        qtd_plantada, qtd_atual, data_plantio
                   FROM vw_area_planta_detalhe
                  WHERE fk_id_garden = :garden
                  ORDER BY planta_nome ASC'
            );
            $stmtPlantas->execute([':garden' => $idGarden]);
            $listaPlantas = $stmtPlantas->fetchAll();

            $stmtCatalogo = $pdo->query(
                'SELECT id_planta, nome_p, necessidade_agua, necessidade_luz,
                        ph_ideal_min, ph_ideal_max, nutricao
                   FROM plantas
                  ORDER BY nome_p ASC'
            );
            $catalogoDb = $stmtCatalogo->fetchAll();

            $plantasPorArea = [];
            foreach ($listaPlantas as $p) {
                $idArea = (int) $p['fk_id_area'];
                $plantasPorArea[$idArea][] = [
                    'idPlanta'  => (int) $p['fk_id_planta'],
                    'id_planta' => (int) $p['fk_id_planta'],
                    'nome'      => $p['planta_nome'],
                    'agua'      => $p['necessidade_agua'],
                    'luz'       => $p['necessidade_luz'],
                    'phMin'     => (float) $p['ph_ideal_min'],
                    'phMax'     => (float) $p['ph_ideal_max'],
                    'nutricao'  => $p['nutricao'],
                    'qtd'       => (int) ($p['qtd_atual'] > 0 ? $p['qtd_atual'] : $p['qtd_plantada']),
                    'qtdAtual'  => (int) $p['qtd_atual'],
                    'data'      => $p['data_plantio']
                ];
            }

            $areasFormatadas = [];
            foreach ($listaAreas as $a) {
                $idArea = (int) $a['id_area'];
                $areasFormatadas[] = [
                    'id'         => $idArea,
                    'id_area'    => $idArea,
                    'nome'       => $a['area_nome'],
                    'areaM2'     => (float) $a['area_m2'],
                    'umidade'    => $a['umidade'] !== null ? (float) $a['umidade'] : null,
                    'umidadeMin' => (float) $a['umid_min_ideal'],
                    'umidadeMax' => (float) $a['umid_max_ideal'],
                    'ph'         => $a['ph_solo'] !== null ? (float) $a['ph_solo'] : null,
                    'phMin'      => (float) $a['ph_min_ideal'],
                    'phMax'      => (float) $a['ph_max_ideal'],
                    'plantas'    => $plantasPorArea[$idArea] ?? []
                ];
            }

            $catalogoFormatado = [];
            foreach ($catalogoDb as $c) {
                $catalogoFormatado[] = [
                    'id'       => (int) $c['id_planta'],
                    'nome'     => $c['nome_p'],
                    'agua'     => $c['necessidade_agua'],
                    'luz'      => $c['necessidade_luz'],
                    'phMin'    => (float) $c['ph_ideal_min'],
                    'phMax'    => (float) $c['ph_ideal_max'],
                    'nutricao' => $c['nutricao']
                ];
            }

            responder(200, 'sucesso', 'Dados carregados com sucesso.', [
                'areas'    => $areasFormatadas,
                'catalogo' => $catalogoFormatado
            ]);
        }

        // 1.2 Resumo geral da estufa (usado por index_dashboard.js)
        if ($acao === 'resumo_dashboard') {
            $stmtResumo = $pdo->prepare('SELECT * FROM vw_dash_resumo WHERE id_garden = :g LIMIT 1');
            $stmtResumo->execute([':g' => $idGarden]);
            $resumo = $stmtResumo->fetch() ?: [];

            $stmtAreas = $pdo->prepare(
                'SELECT id_area, area_nome, status_umidade, umidade, ph_solo
                   FROM vw_dash_area
                  WHERE fk_id_garden = :g
                  ORDER BY id_area ASC'
            );
            $stmtAreas->execute([':g' => $idGarden]);
            $areasDb = $stmtAreas->fetchAll();

            $areasFormatadas = [];
            $somaUmidadeSolo = 0.0;
            $contUmidadeSolo = 0;

            foreach ($areasDb as $ar) {
                $areasFormatadas[] = [
                    'id_area' => (int) $ar['id_area'],
                    'nome'    => $ar['area_nome'],
                    'umidade' => $ar['umidade'] !== null ? (float) $ar['umidade'] : null,
                    'ph'      => $ar['ph_solo'] !== null ? (float) $ar['ph_solo'] : null,
                    'status'  => strtoupper($ar['status_umidade'])
                ];
                if ($ar['umidade'] !== null) {
                    $somaUmidadeSolo += (float) $ar['umidade'];
                    $contUmidadeSolo++;
                }
            }

            $stmtTemp = $pdo->prepare("SELECT valor FROM vw_dash_sensor WHERE id_garden = :g AND tipo = 'ambiente' LIMIT 1");
            $stmtTemp->execute([':g' => $idGarden]);
            $temperatura = $stmtTemp->fetchColumn();

            $stmtInsumos = $pdo->prepare(
                'SELECT id_insumo, nome_ins, categoria, unidade, estoque, lmt_min, consumo_total, status
                   FROM vw_dash_insumo
                  WHERE id_garden = :g
                  ORDER BY id_insumo ASC'
            );
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
                'insumos'     => $insumos,
                'estoque'     => [
                    'fertilizante'   => isset($insumos[0]) ? "{$insumos[0]['estoque']} {$insumos[0]['unidade']}" : '--',
                    'substrato'      => isset($insumos[1]) ? "{$insumos[1]['estoque']} {$insumos[1]['unidade']}" : '--',
                    'sementesTomate' => isset($insumos[2]) ? "{$insumos[2]['estoque']} {$insumos[2]['unidade']}" : '--'
                ]
            ]);
        }

        // 1.3 Dados e históricos para a tela index_irrigacao.html
        if ($acao === 'dados_irrigacao') {
            $stmtResumo = $pdo->prepare('SELECT * FROM vw_dash_resumo WHERE id_garden = :g LIMIT 1');
            $stmtResumo->execute([':g' => $idGarden]);
            $resumo = $stmtResumo->fetch() ?: [];

            $stmtAreas = $pdo->prepare(
                'SELECT id_area, area_nome, umidade, ph_solo, status_umidade, status_ph, volume_ideal_l
                   FROM vw_dash_area
                  WHERE fk_id_garden = :g
                  ORDER BY id_area ASC'
            );
            $stmtAreas->execute([':g' => $idGarden]);
            $areas = $stmtAreas->fetchAll();

            $somaUmid = 0.0;
            $contUmid = 0;
            foreach ($areas as $ar) {
                if ($ar['umidade'] !== null) {
                    $somaUmid += (float) $ar['umidade'];
                    $contUmid++;
                }
            }
            $umidadeSoloMedia = $contUmid > 0 ? round($somaUmid / $contUmid, 1) : null;

            $stmtTemp = $pdo->prepare("SELECT valor FROM vw_dash_sensor WHERE id_garden = :g AND tipo = 'ambiente' LIMIT 1");
            $stmtTemp->execute([':g' => $idGarden]);
            $tempAtual = $stmtTemp->fetchColumn();

            $stmtLeituras = $pdo->prepare(
                "SELECT ls.id_leitura, sc.`local` AS local_sensor, sc.tipo, ls.valor,
                        ls.origem, ls.data_hora,
                        COALESCE(NULLIF(u.nome_comp, ''), u.email, 'Sistema') AS responsavel
                   FROM leitura_sensor ls
                   JOIN sensor_controle sc ON sc.id_sensor_controle = ls.fk_id_sensor
                   LEFT JOIN usuario u ON u.id_usuario = ls.fk_id_usuario
                  WHERE sc.tipo IN ('ambiente', 'umidade', 'ph_solo')
                  ORDER BY ls.data_hora DESC, ls.id_leitura DESC
                  LIMIT 30"
            );
            $stmtLeituras->execute();
            $leituras = $stmtLeituras->fetchAll();

            $stmtIrr = $pdo->prepare(
                "SELECT h.id_historico, a.nome AS area_nome, h.tempo_efetivo_min,
                        h.agua_usada_l, h.tipo_acionamento, h.data_hora,
                        COALESCE(NULLIF(u.nome_comp, ''), u.email, 'Sistema') AS responsavel
                   FROM hist_irrigacao h
                   JOIN area a ON a.id_area = h.fk_id_area
                   LEFT JOIN usuario u ON u.id_usuario = h.fk_id_usuario
                  WHERE a.fk_id_garden = :g
                  ORDER BY h.data_hora DESC, h.id_historico DESC
                  LIMIT 30"
            );
            $stmtIrr->execute([':g' => $idGarden]);
            $irrigacoes = $stmtIrr->fetchAll();

            responder(200, 'sucesso', 'Dados de irrigação carregados.', [
                'temperatura_atual'  => ($tempAtual !== false && $tempAtual !== null) ? (float) $tempAtual : null,
                'umidade_solo_media' => $umidadeSoloMedia,
                'bomba_ligada'       => !empty($resumo['irrigacao_ligada']),
                'nivel_agua_pct'     => (float) ($resumo['nivel_agua_pct'] ?? 0),
                'volume_agua_l'      => (float) ($resumo['volume_agua_l'] ?? 0),
                'irrigacao_nome'     => $resumo['irrigacao_nome'] ?? 'Sistema',
                'irrigacao_vazao_l'  => isset($resumo['irrigacao_vazao_l']) ? (float) $resumo['irrigacao_vazao_l'] : null,
                'ultima_irrigacao'   => $resumo['ultima_irrigacao'] ?? 'Automática',
                'areas'              => $areas,
                'leituras'           => $leituras,
                'irrigacoes'         => $irrigacoes
            ]);
        }

        // 1.4 Estoque de insumos + áreas + histórico de movimentações (index_estoque.html)
        if ($acao === 'listar_insumos') {
            $stmtInsumos = $pdo->prepare(
                'SELECT id_insumo, nome_ins, categoria, unidade, estoque, lmt_min, consumo_total, status
                   FROM vw_dash_insumo
                  WHERE id_garden = :g
                  ORDER BY id_insumo ASC'
            );
            $stmtInsumos->execute([':g' => $idGarden]);
            $insumos = $stmtInsumos->fetchAll();

            $stmtAreas = $pdo->prepare(
                'SELECT id_area, nome AS area_nome
                   FROM area
                  WHERE fk_id_garden = :g
                  ORDER BY id_area ASC'
            );
            $stmtAreas->execute([':g' => $idGarden]);
            $areas = $stmtAreas->fetchAll();

            $stmtMov = $pdo->prepare(
                "(SELECT 'entrada' AS tipo, e.data_hora, i.nome_ins, e.quantidade, i.unidade,
                         NULL AS area_nome, 'reposicao' AS motivo, e.observacao,
                         COALESCE(NULLIF(u.nome_comp, ''), u.email, 'Sistema') AS responsavel
                    FROM entrada_insumo e
                    JOIN insumo i ON i.id_insumo = e.fk_id_insumo
                    LEFT JOIN usuario u ON u.id_usuario = e.fk_id_usuario
                   WHERE i.fk_id_garden = :g1)
                 UNION ALL
                 (SELECT 'consumo' AS tipo, c.data_hora, i.nome_ins, c.qtd_aplicada AS quantidade, i.unidade,
                         a.nome AS area_nome, c.motivo, c.observacao,
                         COALESCE(NULLIF(u.nome_comp, ''), u.email, 'Sistema') AS responsavel
                    FROM registro_consumo c
                    JOIN insumo i ON i.id_insumo = c.fk_id_insumo
                    JOIN area a ON a.id_area = c.fk_id_area
                    LEFT JOIN usuario u ON u.id_usuario = c.fk_id_usuario
                   WHERE i.fk_id_garden = :g2)
                 ORDER BY data_hora DESC
                 LIMIT 30"
            );
            $stmtMov->execute([':g1' => $idGarden, ':g2' => $idGarden]);
            $movimentacoes = $stmtMov->fetchAll();

            responder(200, 'sucesso', 'Estoque carregado com sucesso.', [
                'insumos'       => $insumos,
                'areas'         => $areas,
                'movimentacoes' => $movimentacoes
            ]);
        }

        // 1.5 Lista relatórios salvos no banco
        if ($acao === 'listar_relatorios') {
            $stmt = $pdo->prepare(
                'SELECT * FROM vw_relatorio_lista
                  WHERE id_garden = :g
                  ORDER BY gerado_em DESC, id_relatorio DESC'
            );
            $stmt->execute([':g' => $idGarden]);
            responder(200, 'sucesso', 'Relatórios carregados.', [
                'relatorios' => $stmt->fetchAll()
            ]);
        }

        // 1.6 Busca todas as 7 seções de um relatório específico
        if ($acao === 'detalhe_relatorio') {
            $idRel = (int) ($_GET['id'] ?? 0);
            if ($idRel <= 0) {
                responder(422, 'erro', 'ID de relatório inválido.');
            }

            $stmtCab = $pdo->prepare('SELECT * FROM relatorio WHERE id_relatorio = :id AND fk_id_garden = :g');
            $stmtCab->execute([':id' => $idRel, ':g' => $idGarden]);
            $cabecalho = $stmtCab->fetch();

            if (!$cabecalho) {
                responder(404, 'erro', 'Relatório não encontrado.');
            }

            $buscarSecao = function (string $tabela) use ($pdo, $idRel): array {
                $st = $pdo->prepare("SELECT * FROM {$tabela} WHERE fk_id_relatorio = :id");
                $st->execute([':id' => $idRel]);
                return $st->fetchAll();
            };

            responder(200, 'sucesso', 'Detalhes do relatório carregados.', [
                'cabecalho'     => $cabecalho,
                'areas'         => $buscarSecao('rel_area'),
                'plantas'       => $buscarSecao('rel_area_planta'),
                'reservatorios' => $buscarSecao('rel_reservatorio'),
                'irrigacoes'    => $buscarSecao('rel_irrigacao'),
                'sensores'      => $buscarSecao('rel_sensor'),
                'insumos'       => $buscarSecao('rel_insumo'),
                'alertas'       => $buscarSecao('rel_alerta')
            ]);
        }

        responder(400, 'erro', 'Ação GET desconhecida.');
    } catch (PDOException $e) {
        error_log('Erro no GET dashboard_data.php: ' . $e->getMessage());
        responder(500, 'erro', 'Erro ao consultar o banco: ' . $e->getMessage());
    }
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

    // AÇÃO 1: CRIAR NOVA ÁREA
    if ($acao === 'area') {
        $nome       = trim($dados['nome'] ?? '');
        $umidadeMin = isset($dados['umidade_min']) ? (float) $dados['umidade_min'] : 30.0;
        $umidadeMax = isset($dados['umidade_max']) ? (float) $dados['umidade_max'] : 70.0;
        $phMin      = isset($dados['ph_min']) ? (float) $dados['ph_min'] : 6.0;
        $phMax      = isset($dados['ph_max']) ? (float) $dados['ph_max'] : 7.0;
        $areaM2     = (isset($dados['area_m2']) && $dados['area_m2'] !== null && (float) $dados['area_m2'] > 0)
                        ? (float) $dados['area_m2']
                        : 10.0;

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

        $stmtSensor = $pdo->prepare("INSERT INTO sensor_controle (`local`, tipo) VALUES (:local, 'umidade')");
        $stmtSensor->execute([':local' => $nome]);
        $idSensorUmid = (int) $pdo->lastInsertId();

        $pdo->prepare('INSERT INTO sensor_umidade (id_sensor_controle, umid_min, umid_max) VALUES (:id, :min, :max)')
            ->execute([':id' => $idSensorUmid, ':min' => $umidadeMin, ':max' => $umidadeMax]);

        $stmtSensorPh = $pdo->prepare("INSERT INTO sensor_controle (`local`, tipo) VALUES (:local, 'ph_solo')");
        $stmtSensorPh->execute([':local' => $nome]);
        $idSensorPh = (int) $pdo->lastInsertId();

        $pdo->prepare('INSERT INTO sensor_ph_solo (id_sensor_controle, phs_min, phs_max) VALUES (:id, :min, :max)')
            ->execute([':id' => $idSensorPh, ':min' => $phMin, ':max' => $phMax]);

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
        responder(201, 'sucesso', 'Área criada com sucesso!', ['id' => $idArea, 'id_area' => $idArea]);
    }

    // AÇÃO 1.1: REMOVER ÁREA
    if ($acao === 'remover_area') {
        $idArea = (int) ($dados['id_area'] ?? 0);
        if ($idArea <= 0) {
            responder(422, 'erro', 'ID de área inválido.');
        }

        $stmt = $pdo->prepare(
            'SELECT fk_id_sensor_umidade, fk_id_sensor_ph_solo
               FROM area
              WHERE id_area = :id AND fk_id_garden = :g
              LIMIT 1'
        );
        $stmt->execute([':id' => $idArea, ':g' => $idGarden]);
        $sensores = $stmt->fetch();

        if (!$sensores) {
            responder(404, 'erro', 'Área não encontrada.');
        }

        $pdo->beginTransaction();
        $pdo->prepare('DELETE FROM area WHERE id_area = :id AND fk_id_garden = :g')
            ->execute([':id' => $idArea, ':g' => $idGarden]);

        $pdo->prepare('DELETE FROM sensor_controle WHERE id_sensor_controle IN (:s1, :s2)')
            ->execute([
                ':s1' => (int) $sensores['fk_id_sensor_umidade'],
                ':s2' => (int) $sensores['fk_id_sensor_ph_solo']
            ]);

        $pdo->commit();
        responder(200, 'sucesso', 'Área removida com sucesso.');
    }

    // AÇÃO 2: CADASTRAR NOVA ESPÉCIE NO CATÁLOGO (e opcionalmente vincular à área se area_nome for enviado)
    if ($acao === 'planta') {
        $nomeArea = trim($dados['area_nome'] ?? '');
        $nome     = trim($dados['nome'] ?? '');
        $agua     = $dados['agua'] ?? 'media';
        $luz      = $dados['luz'] ?? 'sol_pleno';
        $nutricao = $dados['nutricao'] ?? 'media';
        $phMin    = isset($dados['ph_min']) ? (float) $dados['ph_min'] : 6.0;
        $phMax    = isset($dados['ph_max']) ? (float) $dados['ph_max'] : 7.0;
        $qtd      = isset($dados['qtd_plantada']) && (int) $dados['qtd_plantada'] > 0 ? (int) $dados['qtd_plantada'] : 10;

        if ($luz === 'sombra') {
            $luz = 'meia_sombra';
        }
        if ($nome === '' || mb_strlen($nome) > 100) {
            responder(422, 'erro', 'Informe o nome da espécie (até 100 caracteres).');
        }
        if ($phMin < 0 || $phMax > 14 || $phMin >= $phMax) {
            responder(422, 'erro', 'O pH mínimo deve ser menor que o pH máximo (entre 0 e 14).');
        }

        // Modo catálogo (sem area_nome): cadastra nova espécie em `plantas`
        if ($nomeArea === '') {
            $stmtIns = $pdo->prepare(
                'INSERT INTO plantas (nome_p, necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao)
                 VALUES (:nome, :agua, :luz, :ph_min, :ph_max, :nutricao)'
            );
            $stmtIns->execute([
                ':nome' => $nome, ':agua' => $agua, ':luz' => $luz,
                ':ph_min' => $phMin, ':ph_max' => $phMax, ':nutricao' => $nutricao
            ]);
            $idPlanta = (int) $pdo->lastInsertId();
            responder(201, 'sucesso', 'Espécie cadastrada no catálogo com sucesso!', ['id' => $idPlanta, 'id_planta' => $idPlanta]);
        }

        // Modo legado (com area_nome): cadastra se não existir e vincula à área
        $stmtBuscaArea = $pdo->prepare('SELECT id_area FROM area WHERE fk_id_garden = :g AND nome = :nome LIMIT 1');
        $stmtBuscaArea->execute([':g' => $idGarden, ':nome' => $nomeArea]);
        $idArea = (int) $stmtBuscaArea->fetchColumn();

        if (!$idArea) {
            responder(404, 'erro', 'Área selecionada não foi encontrada.');
        }

        $pdo->beginTransaction();

        $stmtBuscaPlanta = $pdo->prepare('SELECT id_planta FROM plantas WHERE nome_p = :nome LIMIT 1');
        $stmtBuscaPlanta->execute([':nome' => $nome]);
        $idPlanta = (int) $stmtBuscaPlanta->fetchColumn();

        if (!$idPlanta) {
            $pdo->prepare(
                'INSERT INTO plantas (nome_p, necessidade_agua, necessidade_luz, ph_ideal_min, ph_ideal_max, nutricao)
                 VALUES (:nome, :agua, :luz, :ph_min, :ph_max, :nutricao)'
            )->execute([
                ':nome' => $nome, ':agua' => $agua, ':luz' => $luz,
                ':ph_min' => $phMin, ':ph_max' => $phMax, ':nutricao' => $nutricao
            ]);
            $idPlanta = (int) $pdo->lastInsertId();
        }

        $stmtExiste = $pdo->prepare('SELECT 1 FROM area_planta WHERE fk_id_area = :area AND fk_id_planta = :planta');
        $stmtExiste->execute([':area' => $idArea, ':planta' => $idPlanta]);
        if ($stmtExiste->fetchColumn()) {
            $pdo->rollBack();
            responder(409, 'erro', 'Esta planta já está cultivada nesta área.');
        }

        $pdo->prepare('INSERT INTO area_planta (fk_id_area, fk_id_planta, qtd_plantada, data_plantio) VALUES (:area, :planta, :qtd, CURRENT_DATE)')
            ->execute([':area' => $idArea, ':planta' => $idPlanta, ':qtd' => $qtd]);

        $idEstagio = (int) ($pdo->query("SELECT id_estagio FROM estagio_planta WHERE nome = 'broto' LIMIT 1")->fetchColumn() ?: 1);
        $pdo->prepare('INSERT INTO area_planta_estagio (fk_id_area, fk_id_planta, fk_id_estagio, quantidade) VALUES (:area, :planta, :estagio, :qtd)')
            ->execute([':area' => $idArea, ':planta' => $idPlanta, ':estagio' => $idEstagio, ':qtd' => $qtd]);

        $pdo->commit();
        responder(201, 'sucesso', 'Planta salva e vinculada à área com sucesso!', ['id' => $idPlanta, 'id_planta' => $idPlanta]);
    }

    // AÇÃO 2.1: REGISTRAR PLANTIO DE UMA ESPÉCIE DO CATÁLOGO EM UMA ÁREA
    if ($acao === 'plantio') {
        $idArea      = (int) ($dados['id_area'] ?? 0);
        $idPlanta    = (int) ($dados['id_planta'] ?? 0);
        $qtd         = (int) ($dados['qtd_plantada'] ?? 0);
        $dataPlantio = trim($dados['data_plantio'] ?? date('Y-m-d'));

        if ($idArea <= 0 || $idPlanta <= 0) {
            responder(422, 'erro', 'Selecione uma área e uma espécie válidas.');
        }
        if ($qtd <= 0) {
            responder(422, 'erro', 'A quantidade plantada deve ser maior que zero.');
        }
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $dataPlantio)) {
            $dataPlantio = date('Y-m-d');
        }

        $stmtArea = $pdo->prepare('SELECT 1 FROM area WHERE id_area = :id AND fk_id_garden = :g');
        $stmtArea->execute([':id' => $idArea, ':g' => $idGarden]);
        if (!$stmtArea->fetchColumn()) {
            responder(404, 'erro', 'Área selecionada não foi encontrada.');
        }

        $stmtExiste = $pdo->prepare('SELECT 1 FROM area_planta WHERE fk_id_area = :area AND fk_id_planta = :planta');
        $stmtExiste->execute([':area' => $idArea, ':planta' => $idPlanta]);
        if ($stmtExiste->fetchColumn()) {
            responder(409, 'erro', 'Esta espécie já está plantada nesta área.');
        }

        $pdo->beginTransaction();

        $pdo->prepare(
            'INSERT INTO area_planta (fk_id_area, fk_id_planta, qtd_plantada, data_plantio)
             VALUES (:area, :planta, :qtd, :data)'
        )->execute([
            ':area'   => $idArea,
            ':planta' => $idPlanta,
            ':qtd'    => $qtd,
            ':data'   => $dataPlantio
        ]);

        $idEstagio = (int) ($pdo->query("SELECT id_estagio FROM estagio_planta WHERE nome = 'broto' LIMIT 1")->fetchColumn() ?: 1);
        $pdo->prepare(
            'INSERT INTO area_planta_estagio (fk_id_area, fk_id_planta, fk_id_estagio, quantidade)
             VALUES (:area, :planta, :estagio, :qtd)'
        )->execute([
            ':area'    => $idArea,
            ':planta'  => $idPlanta,
            ':estagio' => $idEstagio,
            ':qtd'     => $qtd
        ]);

        $pdo->commit();
        responder(201, 'sucesso', 'Plantio registrado com sucesso!');
    }

    // AÇÃO 2.2: REMOVER ESPÉCIE DO CATÁLOGO
    if ($acao === 'remover_especie') {
        $idPlanta = (int) ($dados['id_planta'] ?? 0);
        if ($idPlanta <= 0) {
            responder(422, 'erro', 'ID da espécie inválido.');
        }

        $stmt = $pdo->prepare('DELETE FROM plantas WHERE id_planta = :id');
        $stmt->execute([':id' => $idPlanta]);
        if ($stmt->rowCount() === 0) {
            responder(404, 'erro', 'Espécie não encontrada.');
        }
        responder(200, 'sucesso', 'Espécie excluída do catálogo com sucesso.');
    }

    // AÇÃO 3: REMOVER PLANTA DA ÁREA
    if ($acao === 'remover_planta') {
        $idArea   = (int) ($dados['id_area'] ?? 0);
        $idPlanta = (int) ($dados['id_planta'] ?? 0);
        if ($idArea <= 0 || $idPlanta <= 0) {
            responder(422, 'erro', 'IDs de área e planta inválidos.');
        }
        $pdo->prepare('DELETE FROM area_planta WHERE fk_id_area = :area AND fk_id_planta = :planta')
            ->execute([':area' => $idArea, ':planta' => $idPlanta]);
        responder(200, 'sucesso', 'Planta removida da área com sucesso.');
    }

    // AÇÃO 4: LIGAR/DESLIGAR BOMBA DE IRRIGAÇÃO
    if ($acao === 'toggle_irrigacao') {
        $pdo->prepare(
            'UPDATE sistema_irrigacao si
               JOIN garden g ON g.fk_id_sist_irriga = si.id_sis_irr
                SET si.lig_bol = IF(si.lig_bol = 1, 0, 1)
              WHERE g.id_garden = :g'
        )->execute([':g' => $idGarden]);
        responder(200, 'sucesso', 'Status do sistema de irrigação atualizado.');
    }

    // AÇÃO 5: SALVAR LEITURA MANUAL NO CANTEIRO ESCOLHIDO
    if ($acao === 'leitura_manual') {
        $idArea      = (int) ($dados['id_area'] ?? 0);
        $temperatura = (isset($dados['temperatura']) && $dados['temperatura'] !== '' && is_numeric($dados['temperatura'])) ? (float) $dados['temperatura'] : null;
        $umidadeSolo = (isset($dados['umidade_solo']) && $dados['umidade_solo'] !== '' && is_numeric($dados['umidade_solo'])) ? (float) $dados['umidade_solo'] : null;
        $phSolo      = (isset($dados['ph_solo']) && $dados['ph_solo'] !== '' && is_numeric($dados['ph_solo'])) ? (float) $dados['ph_solo'] : null;
        $idUsuario   = obterIdUsuarioAtual($pdo);

        if ($temperatura === null && $umidadeSolo === null && $phSolo === null) {
            responder(422, 'erro', 'Preencha pelo menos um valor numérico de leitura.');
        }

        $sensoresArea = null;
        if ($umidadeSolo !== null || $phSolo !== null) {
            if ($idArea <= 0) {
                responder(422, 'erro', 'Selecione qual canteiro está sendo modificado.');
            }
            $stmtArea = $pdo->prepare(
                'SELECT fk_id_sensor_umidade, fk_id_sensor_ph_solo FROM area WHERE id_area = :id AND fk_id_garden = :g LIMIT 1'
            );
            $stmtArea->execute([':id' => $idArea, ':g' => $idGarden]);
            $sensoresArea = $stmtArea->fetch();

            if (!$sensoresArea) {
                responder(404, 'erro', 'Canteiro não encontrado no banco.');
            }
        }

        $pdo->beginTransaction();

        $stmtIns = $pdo->prepare(
            "INSERT INTO leitura_sensor (fk_id_sensor, valor, origem, fk_id_usuario)
             VALUES (:sensor, :valor, 'manual', :usuario)"
        );

        if ($temperatura !== null) {
            $stmtAmb = $pdo->prepare('SELECT fk_id_sensor_ambiente FROM garden WHERE id_garden = :g LIMIT 1');
            $stmtAmb->execute([':g' => $idGarden]);
            $idSensorAmb = (int) $stmtAmb->fetchColumn();
            if ($idSensorAmb) {
                $stmtIns->execute([':sensor' => $idSensorAmb, ':valor' => $temperatura, ':usuario' => $idUsuario]);
            }
        }

        if ($umidadeSolo !== null && $sensoresArea) {
            $stmtIns->execute([':sensor' => (int) $sensoresArea['fk_id_sensor_umidade'], ':valor' => $umidadeSolo, ':usuario' => $idUsuario]);
        }

        if ($phSolo !== null && $sensoresArea) {
            $stmtIns->execute([':sensor' => (int) $sensoresArea['fk_id_sensor_ph_solo'], ':valor' => $phSolo, ':usuario' => $idUsuario]);
        }

        $pdo->commit();
        responder(201, 'sucesso', 'Leitura manual registrada com sucesso!');
    }

    // AÇÃO 6: ACIONAR IRRIGAÇÃO EM UM CANTEIRO VIA PROCEDURE
    if ($acao === 'acionar_irrigacao') {
        $idArea    = (int) ($dados['id_area'] ?? 0);
        $minutos   = (isset($dados['minutos']) && $dados['minutos'] !== '' && is_numeric($dados['minutos'])) ? (float) $dados['minutos'] : null;
        $tipo      = $dados['tipo'] ?? 'manual';
        $idUsuario = obterIdUsuarioAtual($pdo);

        if ($idArea <= 0) {
            responder(422, 'erro', 'Selecione o canteiro para irrigar.');
        }

        $stmtCaixa = $pdo->prepare('SELECT id_caixa FROM caixa_dagua WHERE fk_id_garden = :g ORDER BY vol_atual DESC LIMIT 1');
        $stmtCaixa->execute([':g' => $idGarden]);
        $idCaixa = (int) $stmtCaixa->fetchColumn();

        if (!$idCaixa) {
            responder(404, 'erro', 'Nenhuma caixa d\'água cadastrada na estufa.');
        }

        $stmt = $pdo->prepare('CALL sp_irrigar_area(:area, :caixa, :min, :tipo, :usr)');
        $stmt->execute([
            ':area'  => $idArea,
            ':caixa' => $idCaixa,
            ':min'   => $minutos,
            ':tipo'  => $tipo,
            ':usr'   => $idUsuario
        ]);
        $res = $stmt->fetch();
        $stmt->closeCursor();

        responder(200, 'sucesso', 'Irrigação realizada com sucesso!', ['resultado' => $res]);
    }

    // AÇÃO 7: REPOSIÇÃO DE ESTOQUE (ENTRADA DE INSUMO)
    if ($acao === 'entrada_insumo') {
        $idInsumo   = (int) ($dados['id_insumo'] ?? 0);
        $quantidade = isset($dados['quantidade']) && is_numeric($dados['quantidade']) ? (float) $dados['quantidade'] : 0.0;
        $observacao = trim($dados['observacao'] ?? '');
        $idUsuario  = obterIdUsuarioAtual($pdo);

        if ($idInsumo <= 0) {
            responder(422, 'erro', 'Selecione um insumo válido.');
        }
        if ($quantidade <= 0) {
            responder(422, 'erro', 'A quantidade de reposição deve ser maior que zero.');
        }
        if (!$idUsuario) {
            responder(401, 'erro', 'Usuário não identificado para registrar a movimentação.');
        }

        $stmtCheck = $pdo->prepare('SELECT 1 FROM insumo WHERE id_insumo = :id AND fk_id_garden = :g');
        $stmtCheck->execute([':id' => $idInsumo, ':g' => $idGarden]);
        if (!$stmtCheck->fetchColumn()) {
            responder(404, 'erro', 'Insumo não encontrado nesta estufa.');
        }

        $stmt = $pdo->prepare(
            'INSERT INTO entrada_insumo (fk_id_insumo, quantidade, fk_id_usuario, observacao)
             VALUES (:insumo, :qtd, :usr, :obs)'
        );
        $stmt->execute([
            ':insumo' => $idInsumo,
            ':qtd'    => $quantidade,
            ':usr'    => $idUsuario,
            ':obs'    => $observacao !== '' ? mb_substr($observacao, 0, 200) : null
        ]);

        responder(201, 'sucesso', 'Entrada de estoque registrada com sucesso!');
    }

    // AÇÃO 8: CONSUMO / APLICAÇÃO DE INSUMO (SAÍDA)
    if ($acao === 'consumo_insumo') {
        $idInsumo   = (int) ($dados['id_insumo'] ?? 0);
        $idArea     = (int) ($dados['id_area'] ?? 0);
        $quantidade = isset($dados['quantidade']) && is_numeric($dados['quantidade']) ? (float) $dados['quantidade'] : 0.0;
        $motivo     = $dados['motivo'] ?? 'outro';
        $observacao = trim($dados['observacao'] ?? '');
        $idUsuario  = obterIdUsuarioAtual($pdo);

        if (!in_array($motivo, ['correcao_ph', 'adubacao', 'outro'], true)) {
            $motivo = 'outro';
        }
        if ($idInsumo <= 0) {
            responder(422, 'erro', 'Selecione um insumo válido.');
        }
        if ($idArea <= 0) {
            responder(422, 'erro', 'Selecione o canteiro onde o insumo foi aplicado.');
        }
        if ($quantidade <= 0) {
            responder(422, 'erro', 'A quantidade aplicada deve ser maior que zero.');
        }
        if (!$idUsuario) {
            responder(401, 'erro', 'Usuário não identificado para registrar o consumo.');
        }

        // Triggers trg_consumo_bi e trg_consumo_ai validam saldo e abatem automaticamente
        $stmt = $pdo->prepare(
            'INSERT INTO registro_consumo (qtd_aplicada, motivo, observacao, fk_id_insumo, fk_id_area, fk_id_usuario)
             VALUES (:qtd, :motivo, :obs, :insumo, :area, :usr)'
        );
        $stmt->execute([
            ':qtd'    => $quantidade,
            ':motivo' => $motivo,
            ':obs'    => $observacao !== '' ? mb_substr($observacao, 0, 200) : null,
            ':insumo' => $idInsumo,
            ':area'   => $idArea,
            ':usr'    => $idUsuario
        ]);

        responder(201, 'sucesso', 'Consumo de insumo registrado com sucesso!');
    }

    // AÇÃO 9: CADASTRAR NOVO INSUMO
    if ($acao === 'novo_insumo') {
        $nome           = trim($dados['nome_ins'] ?? '');
        $categoria      = $dados['categoria'] ?? 'outro';
        $unidade        = trim($dados['unidade'] ?? 'kg');
        $lmtMin         = (isset($dados['lmt_min']) && $dados['lmt_min'] !== '' && is_numeric($dados['lmt_min']))
                            ? (float) $dados['lmt_min']
                            : null;
        $estoqueInicial = (isset($dados['estoque_inicial']) && $dados['estoque_inicial'] !== '' && is_numeric($dados['estoque_inicial']))
                            ? (float) $dados['estoque_inicial']
                            : 0.0;
        $idUsuario      = obterIdUsuarioAtual($pdo);

        if (!in_array($categoria, ['corretivo_ph', 'fertilizante', 'outro'], true)) {
            $categoria = 'outro';
        }
        if ($nome === '' || mb_strlen($nome) > 100) {
            responder(422, 'erro', 'Informe o nome do insumo (até 100 caracteres).');
        }
        if ($unidade === '' || mb_strlen($unidade) > 10) {
            responder(422, 'erro', 'Informe uma unidade válida (ex.: kg, L, g, un).');
        }
        if ($lmtMin !== null && $lmtMin < 0) {
            responder(422, 'erro', 'O limite mínimo não pode ser negativo.');
        }
        if ($estoqueInicial < 0) {
            responder(422, 'erro', 'O estoque inicial não pode ser negativo.');
        }

        $pdo->beginTransaction();

        $stmtIns = $pdo->prepare(
            'INSERT INTO insumo (fk_id_garden, nome_ins, categoria, unidade, lmt_min)
             VALUES (:g, :nome, :cat, :uni, :lmt)'
        );
        $stmtIns->execute([
            ':g'    => $idGarden,
            ':nome' => $nome,
            ':cat'  => $categoria,
            ':uni'  => $unidade,
            ':lmt'  => $lmtMin
        ]);
        $idInsumo = (int) $pdo->lastInsertId();

        if ($estoqueInicial > 0 && $idUsuario) {
            $pdo->prepare(
                "INSERT INTO entrada_insumo (fk_id_insumo, quantidade, fk_id_usuario, observacao)
                 VALUES (:insumo, :qtd, :usr, 'estoque inicial')"
            )->execute([
                ':insumo' => $idInsumo,
                ':qtd'    => $estoqueInicial,
                ':usr'    => $idUsuario
            ]);
        }

        $pdo->commit();
        responder(201, 'sucesso', 'Novo insumo cadastrado com sucesso!', ['id_insumo' => $idInsumo]);
    }

    // AÇÃO 10: GERAR RELATÓRIO VIA PROCEDURE
    if ($acao === 'gerar_relatorio') {
        $tipo      = $dados['tipo'] ?? 'completo';
        $idUsuario = obterIdUsuarioAtual($pdo);

        $stmt = $pdo->prepare('CALL sp_gerar_relatorio(:g, :usr, :tipo, NULL, NULL)');
        $stmt->execute([
            ':g'    => $idGarden,
            ':usr'  => $idUsuario,
            ':tipo' => $tipo
        ]);
        $res = $stmt->fetch();
        $stmt->closeCursor();

        responder(201, 'sucesso', 'Relatório gerado com sucesso!', ['relatorio' => $res]);
    }

    responder(400, 'erro', 'Ação desconhecida.');

} catch (PDOException $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    $sqlState  = $e->getCode();
    $mysqlCode = (int) ($e->errorInfo[1] ?? 0);
    $mysqlMsg  = $e->errorInfo[2] ?? $e->getMessage();

    if ($sqlState === '45000' || $mysqlCode === 1644) {
        responder(422, 'erro', $mysqlMsg);
    }
    if ($mysqlCode === 1062) {
        responder(409, 'erro', 'Já existe um registro com esse nome no banco de dados.');
    }
    if ($mysqlCode === 1451) {
        responder(409, 'erro', 'Não é possível remover este registro pois há histórico ou plantio vinculado.');
    }

    error_log('Erro no POST dashboard_data.php: ' . $e->getMessage());
    responder(500, 'erro', 'Erro ao gravar no banco: ' . $mysqlMsg);
}
