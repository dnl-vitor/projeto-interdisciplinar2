/**
 * Arquivo: indexes/index_relatorios.js
 * Objetivo: Gerar, listar, visualizar todas as 7 seções do relatório em formato
 *           de documento limpo na web e exportar PDF em formato de documento simples.
 */

const API = "dashboard_data.php";
let relatorioAtual = null;

const $ = (id) => document.getElementById(id);

function mostrarMensagem(texto, tipo = "ok") {
    const el = $("msg-relatorio");
    if (!el) return;
    el.textContent = texto;
    el.className = "msg-feedback " + (tipo === "erro" ? "erro" : "ok");
    el.hidden = false;
}

function formatarData(iso) {
    if (!iso) return "--";
    const d = new Date(String(iso).replace(" ", "T"));
    return isNaN(d) ? iso : d.toLocaleString("pt-BR");
}

function formatarEstagios(estagios) {
    if (!estagios) return "--";
    try {
        const obj = typeof estagios === "string" ? JSON.parse(estagios) : estagios;
        return Object.entries(obj).map(([k, v]) => `${k}: ${v}`).join(", ");
    } catch {
        return String(estagios);
    }
}

function montarHtmlRelatorio(res) {
    const cab = res.cabecalho;
    const responsavel = cab.usuario_nome || (cab.origem === "agendado" ? "Sistema (automático)" : "Administrador");

    let html = `
        <div class="doc-header">
            <div>
                <div class="doc-brand">GIE — Gestão Inteligente de Estufas</div>
                <h2>Relatório #${cab.id_relatorio} — ${cab.garden_nome}</h2>
            </div>
            <div class="doc-tag">${String(cab.tipo).toUpperCase()}</div>
        </div>
        <div class="meta-info">
            <div><strong>Gerado em:</strong> ${formatarData(cab.gerado_em)}</div>
            <div><strong>Responsável:</strong> ${responsavel} (${cab.origem})</div>
            <div><strong>Período analisado:</strong> ${formatarData(cab.periodo_inicio)} até ${formatarData(cab.periodo_fim)}</div>
            <div><strong>Sistema de Irrigação:</strong> ${cab.irrigacao_nome || "--"} (${cab.irrigacao_ligada ? "Ligado" : "Desligado"} · ${cab.irrigacao_vazao_l ?? "--"} L/min)</div>
        </div>
    `;

    // 1. Áreas de Cultivo
    if (res.areas && res.areas.length > 0) {
        html += `<h3>1. Áreas de Cultivo</h3><div class="doc-table-wrap"><table>
            <thead><tr>
                <th>Área</th><th>m²</th><th>Espécies</th><th>Plantas</th>
                <th>Umidade (Ideal)</th><th>Status Umid.</th>
                <th>pH (Ideal)</th><th>Status pH</th><th>Vol. Ideal</th><th>Irrigar?</th>
            </tr></thead><tbody>`;
        res.areas.forEach((a) => {
            html += `<tr>
                <td><strong>${a.area_nome}</strong></td>
                <td>${a.area_m2}</td>
                <td>${a.qtd_especies}</td>
                <td>${a.qtd_plantas}</td>
                <td>${a.umidade ?? "--"}% (${a.umid_min_ideal ?? "--"}–${a.umid_max_ideal ?? "--"}%)</td>
                <td>${a.status_umidade}</td>
                <td>${a.ph_solo ?? "--"} (${a.ph_min_ideal ?? "--"}–${a.ph_max_ideal ?? "--"})</td>
                <td>${a.status_ph}</td>
                <td>${a.volume_ideal_l} L</td>
                <td>${Number(a.precisa_irrigar) ? "Sim" : "Não"}</td>
            </tr>`;
        });
        html += `</tbody></table></div>`;
    }

    // 2. Plantas Cultivadas
    if (res.plantas && res.plantas.length > 0) {
        html += `<h3>2. Plantas por Área</h3><div class="doc-table-wrap"><table>
            <thead><tr>
                <th>Área</th><th>Planta</th><th>Água</th><th>Luz</th>
                <th>pH Ideal</th><th>Nutrição</th><th>Plantada / Atual</th>
                <th>Estágios</th><th>Perdas</th>
            </tr></thead><tbody>`;
        res.plantas.forEach((p) => {
            html += `<tr>
                <td>${p.area_nome}</td>
                <td><strong>${p.planta_nome}</strong></td>
                <td>${p.necessidade_agua}</td>
                <td>${p.necessidade_luz}</td>
                <td>${p.ph_ideal_min} – ${p.ph_ideal_max}</td>
                <td>${p.nutricao}</td>
                <td>${p.qtd_plantada} / ${p.qtd_atual}</td>
                <td>${formatarEstagios(p.estagios)}</td>
                <td>${p.perdas_periodo}</td>
            </tr>`;
        });
        html += `</tbody></table></div>`;
    }

    // 3. Reservatórios
    if (res.reservatorios && res.reservatorios.length > 0) {
        html += `<h3>3. Reservatórios (Caixas d'Água)</h3><div class="doc-table-wrap"><table>
            <thead><tr>
                <th>Local</th><th>Capacidade</th><th>Volume Atual</th>
                <th>Nível (%)</th><th>Limite Alerta</th><th>Autonomia</th><th>Status</th>
            </tr></thead><tbody>`;
        res.reservatorios.forEach((r) => {
            html += `<tr>
                <td>${r.sensor_local}</td>
                <td>${r.cap_l} L</td>
                <td>${r.vol_atual_l} L</td>
                <td>${r.nivel_pct}%</td>
                <td>${r.limite_alerta_pct}%</td>
                <td>${r.autonomia_min ?? "--"} min</td>
                <td>${r.status}</td>
            </tr>`;
        });
        html += `</tbody></table></div>`;
    }

    // 4. Resumo de Irrigação
    if (res.irrigacoes && res.irrigacoes.length > 0) {
        html += `<h3>4. Resumo de Irrigação no Período</h3><div class="doc-table-wrap"><table>
            <thead><tr>
                <th>Área</th><th>Acionamentos</th><th>Forçadas</th>
                <th>Total Água (L)</th><th>Total Tempo (min)</th><th>Última Irrigação</th>
            </tr></thead><tbody>`;
        res.irrigacoes.forEach((i) => {
            html += `<tr>
                <td>${i.area_nome}</td>
                <td>${i.qtd_irrigacoes}</td>
                <td>${i.qtd_forcadas}</td>
                <td>${Number(i.litros_total).toFixed(2)} L</td>
                <td>${Number(i.minutos_total).toFixed(2)} min</td>
                <td>${formatarData(i.ultima_irrigacao)}</td>
            </tr>`;
        });
        html += `</tbody></table></div>`;
    }

    // 5. Sensores / Ambiente
    if (res.sensores && res.sensores.length > 0) {
        html += `<h3>5. Sensores e Ambiente</h3><div class="doc-table-wrap"><table>
            <thead><tr>
                <th>Tipo</th><th>Local</th><th>Área</th><th>Valor</th>
                <th>Faixa Ideal</th><th>Status</th><th>Última Leitura</th>
            </tr></thead><tbody>`;
        res.sensores.forEach((s) => {
            const faixa = (s.faixa_min !== null && s.faixa_max !== null)
                ? `${s.faixa_min} a ${s.faixa_max} ${s.unidade || ""}`
                : "--";
            html += `<tr>
                <td>${s.tipo}</td>
                <td>${s.local}</td>
                <td>${s.area_nome || "Estufa"}</td>
                <td>${s.valor ?? "--"} ${s.unidade || ""}</td>
                <td>${faixa}</td>
                <td>${s.status}</td>
                <td>${formatarData(s.lido_em)}</td>
            </tr>`;
        });
        html += `</tbody></table></div>`;
    }

    // 6. Insumos / Estoque
    if (res.insumos && res.insumos.length > 0) {
        html += `<h3>6. Insumos e Estoque</h3><div class="doc-table-wrap"><table>
            <thead><tr>
                <th>Insumo</th><th>Categoria</th><th>Estoque</th><th>Limite Mín.</th>
                <th>Consumo no Período</th><th>Consumo Total</th><th>Status</th>
            </tr></thead><tbody>`;
        res.insumos.forEach((ins) => {
            html += `<tr>
                <td><strong>${ins.nome_ins}</strong></td>
                <td>${ins.categoria}</td>
                <td>${ins.estoque} ${ins.unidade}</td>
                <td>${ins.lmt_min ?? "--"} ${ins.unidade}</td>
                <td>${ins.consumo_periodo} ${ins.unidade}</td>
                <td>${ins.consumo_total} ${ins.unidade}</td>
                <td>${ins.status}</td>
            </tr>`;
        });
        html += `</tbody></table></div>`;
    }

    // 7. Alertas Abertos
    html += `<h3>7. Alertas Abertos no Momento do Relatório</h3>`;
    if (res.alertas && res.alertas.length > 0) {
        html += `<div class="doc-table-wrap"><table>
            <thead><tr><th>Severidade</th><th>Tipo</th><th>Mensagem</th><th>Aberto Desde</th></tr></thead><tbody>`;
        res.alertas.forEach((al) => {
            html += `<tr>
                <td><strong>${String(al.severidade).toUpperCase()}</strong></td>
                <td>${al.tipo}</td>
                <td>${al.mensagem}</td>
                <td>${formatarData(al.aberto_desde)}</td>
            </tr>`;
        });
        html += `</tbody></table></div>`;
    } else {
        html += `<p>Nenhum alerta aberto no momento deste relatório.</p>`;
    }

    html += `<div class="doc-footer">Documento gerado pelo sistema GIE em ${new Date().toLocaleString("pt-BR")}.</div>`;

    return html;
}

function exportarPdfDocumento(dadosRelatorio) {
    const alvo = dadosRelatorio || relatorioAtual;
    if (!alvo) {
        mostrarMensagem("Selecione 'Visualizar' em um relatório ou gere um novo antes de exportar para PDF.", "erro");
        return;
    }

    const janela = window.open("", "_blank");
    if (!janela) {
        alert("O navegador bloqueou a janela do documento PDF. Permita pop-ups para este site.");
        return;
    }

    const corpoRelatorio = montarHtmlRelatorio(alvo);

    janela.document.write(`<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Relatório GIE #${alvo.cabecalho.id_relatorio}</title>
    <style>
        @page { size: A4; margin: 15mm; }
        * { box-sizing: border-box; }
        body {
            font-family: "Segoe UI", Arial, Helvetica, sans-serif;
            font-size: 11.5px;
            color: #1f2933;
            margin: 0;
            padding: 8px;
            line-height: 1.45;
            background: #ffffff;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }
        .doc-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            border-bottom: 2px solid #2b7a4b;
            padding-bottom: 8px;
            margin-bottom: 14px;
        }
        .doc-brand {
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            color: #2b7a4b;
            font-weight: 700;
            margin-bottom: 2px;
        }
        .doc-header h2 {
            margin: 0;
            font-size: 17px;
            color: #111827;
        }
        .doc-tag {
            font-size: 10px;
            font-weight: 700;
            padding: 3px 9px;
            border-radius: 4px;
            background: #e8f5ee;
            color: #2b7a4b;
            border: 1px solid #b8dec8;
        }
        .meta-info {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 4px 16px;
            background: #f8faf9;
            border: 1px solid #d9e2ec;
            border-radius: 5px;
            padding: 10px 12px;
            margin-bottom: 16px;
            font-size: 11px;
        }
        h3 {
            font-size: 13px;
            color: #1f2933;
            margin: 18px 0 6px 0;
            padding-bottom: 3px;
            border-bottom: 1px solid #d9e2ec;
            page-break-after: avoid;
            break-after: avoid;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 10px;
            font-size: 10.5px;
            page-break-inside: auto;
        }
        thead { display: table-header-group; }
        tr { page-break-inside: avoid; break-inside: avoid; }
        th, td {
            border: 1px solid #cbd2d9;
            padding: 5px 7px;
            text-align: left;
            vertical-align: top;
        }
        th {
            background: #eef2f6;
            font-weight: 700;
            color: #1f2933;
        }
        tbody tr:nth-child(even) td {
            background: #fafbfc;
        }
        .doc-footer {
            margin-top: 20px;
            padding-top: 8px;
            border-top: 1px solid #d9e2ec;
            font-size: 10px;
            color: #626b75;
            text-align: right;
        }
    </style>
</head>
<body>
    ${corpoRelatorio}
</body>
</html>`);

    janela.document.close();
    janela.focus();
    setTimeout(() => janela.print(), 350);
}

async function carregarListaRelatorios() {
    try {
        const resp = await fetch(`${API}?acao=listar_relatorios`);
        if (resp.status === 401) {
            window.location.href = "index_cardlogin.html";
            return;
        }
        const res = await resp.json();

        if (!resp.ok || res.status !== "sucesso") {
            throw new Error(res.mensagem || "Erro ao listar relatórios.");
        }

        const tbody = $("tbody-relatorios");
        tbody.innerHTML = "";
        const lista = res.relatorios || [];

        if (lista.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="vazio">Nenhum relatório gerado ainda.</td></tr>`;
            return;
        }

        lista.forEach((r) => {
            const tr = document.createElement("tr");
            tr.innerHTML = `
                <td>#${r.id_relatorio}</td>
                <td>${formatarData(r.gerado_em)}</td>
                <td><strong>${String(r.tipo).toUpperCase()}</strong></td>
                <td>${r.gerado_por}</td>
                <td>${r.n_alertas} (${r.n_alertas_criticos} críticos)</td>
                <td>
                    <div class="acoes">
                        <button type="button" class="btn btn-pequeno" onclick="visualizarRelatorio(${r.id_relatorio})">Visualizar</button>
                        <button type="button" class="btn btn-contorno btn-pequeno" onclick="baixarPdfRelatorio(${r.id_relatorio})">PDF</button>
                    </div>
                </td>
            `;
            tbody.appendChild(tr);
        });
    } catch (erro) {
        console.error(erro);
        mostrarMensagem("Erro ao carregar relatórios: " + erro.message, "erro");
    }
}

async function buscarDetalheRelatorio(id) {
    const resp = await fetch(`${API}?acao=detalhe_relatorio&id=${id}`);
    const res = await resp.json();
    if (!resp.ok || res.status !== "sucesso") {
        throw new Error(res.mensagem || "Erro ao abrir relatório.");
    }
    return res;
}

async function visualizarRelatorio(id) {
    try {
        const res = await buscarDetalheRelatorio(id);
        relatorioAtual = res;
        $("conteudo-relatorio").innerHTML = montarHtmlRelatorio(res);
        $("area-visualizacao-relatorio").hidden = false;
        $("area-visualizacao-relatorio").scrollIntoView({ behavior: "smooth" });
    } catch (erro) {
        console.error(erro);
        mostrarMensagem("Erro ao visualizar relatório: " + erro.message, "erro");
    }
}

async function baixarPdfRelatorio(id) {
    try {
        const res = await buscarDetalheRelatorio(id);
        relatorioAtual = res;
        $("conteudo-relatorio").innerHTML = montarHtmlRelatorio(res);
        $("area-visualizacao-relatorio").hidden = false;
        exportarPdfDocumento(res);
    } catch (erro) {
        console.error(erro);
        mostrarMensagem("Erro ao gerar PDF do relatório: " + erro.message, "erro");
    }
}

document.addEventListener("DOMContentLoaded", () => {
    $("btn-gerar-relatorio").addEventListener("click", async () => {
        const tipo = $("select-tipo-relatorio").value;
        const btn = $("btn-gerar-relatorio");
        btn.disabled = true;
        try {
            const resp = await fetch(API, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ acao: "gerar_relatorio", tipo: tipo })
            });
            const res = await resp.json();

            if (!resp.ok || res.status !== "sucesso") {
                mostrarMensagem("Erro ao gerar relatório: " + (res.mensagem || "Falha desconhecida."), "erro");
                return;
            }

            mostrarMensagem("Relatório gerado e salvo no banco com sucesso!", "ok");
            await carregarListaRelatorios();
            if (res.relatorio && res.relatorio.id_relatorio) {
                await visualizarRelatorio(res.relatorio.id_relatorio);
            }
        } catch (erro) {
            console.error(erro);
            mostrarMensagem("Erro de comunicação com o servidor.", "erro");
        } finally {
            btn.disabled = false;
        }
    });

    $("btn-exportar-pdf").addEventListener("click", () => exportarPdfDocumento(relatorioAtual));
    $("btn-exportar-pdf-doc").addEventListener("click", () => exportarPdfDocumento(relatorioAtual));
    $("btn-atualizar-rel").addEventListener("click", carregarListaRelatorios);

    carregarListaRelatorios();
});
