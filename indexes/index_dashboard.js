/**
 * Arquivo: indexes/index_dashboard.js
 * Objetivo: Carregar os indicadores da Visão Geral (Dashboard)
 *           e controlar o acionamento rápido da bomba de irrigação.
 */

const API = "dashboard_data.php";

async function chamarApi(url, opcoes) {
    const resposta = await fetch(url, opcoes);
    if (resposta.status === 401) {
        window.location.href = "index_cardlogin.html";
        throw new Error("Sessão expirada. Faça login novamente.");
    }
    let corpo = null;
    try {
        corpo = await resposta.json();
    } catch (e) {
        // resposta não JSON
    }
    if (!resposta.ok || !corpo || corpo.status === "erro") {
        throw new Error((corpo && corpo.mensagem) || "Não foi possível falar com o servidor.");
    }
    return corpo;
}

function enviar(dados) {
    return chamarApi(API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(dados)
    });
}

document.addEventListener("DOMContentLoaded", () => {
    const temDados = ["areas-ativas", "lista-estoque-resumo", "status-bomba", "temperatura"]
        .some((id) => document.getElementById(id) !== null);

    if (temDados) {
        carregarDashboard();
        setInterval(() => { if (!document.hidden) carregarDashboard(); }, 10000);
    }

    const btnAtualizar = document.getElementById("btn-atualizar");
    if (btnAtualizar) {
        btnAtualizar.addEventListener("click", async () => {
            btnAtualizar.disabled = true;
            await carregarDashboard();
            btnAtualizar.disabled = false;
        });
    }

    const btnIrrigacao = document.getElementById("btn-irrigacao");
    if (btnIrrigacao) {
        btnIrrigacao.addEventListener("click", async () => {
            btnIrrigacao.disabled = true;
            try {
                await enviar({ acao: "toggle_irrigacao" });
                await carregarDashboard();
            } catch (erro) {
                console.error(erro);
                alert("Não foi possível controlar a irrigação: " + erro.message);
            } finally {
                btnIrrigacao.disabled = false;
            }
        });
    }
});

async function carregarDashboard() {
    const aviso = document.getElementById("aviso");
    try {
        const dados = await chamarApi(`${API}?acao=resumo_dashboard`);

        atualizarAreas(dados);
        atualizarSensores(dados);
        atualizarIrrigacao(dados);
        atualizarEstoque(dados);

        const hora = document.getElementById("atualizado-em");
        if (hora) {
            const agora = new Date();
            hora.textContent = hora.dataset.completo !== undefined
                ? "Gerado em " + agora.toLocaleString("pt-BR")
                : "Atualizado às " + agora.toLocaleTimeString("pt-BR");
        }
        if (aviso) aviso.hidden = true;
    } catch (erro) {
        console.error("Erro ao carregar dashboard:", erro);
        if (aviso) {
            aviso.textContent = "Não foi possível atualizar os dados. Os valores abaixo são da última leitura carregada.";
            aviso.hidden = false;
        }
    }
}

function classeSituacao(texto) {
    const t = String(texto || "").toUpperCase();
    if (/IDEAL|OK|NORMAL|DENTRO/.test(t)) return "st-ok";
    if (/BAIX|ALT|ACIMA|ABAIXO|CRIT|FORA|ATEN|SECO|ENCHARC|ZERAD|INCOMPAT/.test(t)) return "st-alerta";
    return "";
}

function numero(valor, casas) {
    if (valor === null || valor === undefined || valor === "") return "--";
    return Number(valor).toLocaleString("pt-BR", { minimumFractionDigits: casas, maximumFractionDigits: casas });
}

function atualizarAreas(dados) {
    const el = document.getElementById("areas-ativas");
    if (el) {
        el.textContent = el.dataset.numero !== undefined ? dados.areasAtivas : `${dados.areasAtivas} Áreas Ativas`;
    }

    const lista = document.getElementById("lista-areas");
    if (!lista || !Array.isArray(dados.areas)) return;
    lista.innerHTML = "";

    if (lista.tagName === "TBODY") {
        if (dados.areas.length === 0) {
            const tr = document.createElement("tr");
            const td = document.createElement("td");
            td.colSpan = 4;
            td.className = "vazio";
            td.textContent = "Nenhuma área cadastrada. Crie uma em Áreas e Culturas.";
            tr.appendChild(td);
            lista.appendChild(tr);
            return;
        }
        dados.areas.forEach((area) => {
            const tr = document.createElement("tr");
            const celulas = [
                area.nome,
                area.umidade === null || area.umidade === undefined ? "--" : numero(area.umidade, 1) + " %",
                area.ph === null || area.ph === undefined ? "--" : numero(area.ph, 1)
            ];
            celulas.forEach((texto) => {
                const td = document.createElement("td");
                td.textContent = texto;
                tr.appendChild(td);
            });
            const tdSit = document.createElement("td");
            const span = document.createElement("span");
            span.className = "situacao " + classeSituacao(area.status);
            span.textContent = area.status || "--";
            tdSit.appendChild(span);
            tr.appendChild(tdSit);
            lista.appendChild(tr);
        });
        return;
    }

    dados.areas.forEach((area) => {
        const li = document.createElement("li");
        li.textContent = `${area.nome} - ${area.status}`;
        lista.appendChild(li);
    });
}

function atualizarSensores(dados) {
    if (!dados.sensores) return;
    const temp = document.getElementById("temperatura");
    if (temp) temp.textContent = `${dados.sensores.temperatura} °C`;

    const umiAr = document.getElementById("umidade-ar");
    if (umiAr) umiAr.textContent = `${dados.sensores.umidadeAr} %`;

    const umiSolo = document.getElementById("umidade-solo");
    if (umiSolo) umiSolo.textContent = `${dados.sensores.umidadeSolo} %`;
}

function atualizarIrrigacao(dados) {
    if (!dados.irrigacao) return;
    const ligada = !!dados.irrigacao.bombaLigada;

    const statusBomba = document.getElementById("status-bomba");
    if (statusBomba) {
        statusBomba.textContent = ligada ? "Ligada" : "Desligada";
        statusBomba.dataset.ligada = ligada;
    }

    const btn = document.getElementById("btn-irrigacao");
    if (btn && btn.dataset.dinamico !== undefined) {
        btn.textContent = ligada ? "Desligar bomba" : "Ligar bomba";
    }

    const nivelAgua = document.getElementById("nivel-agua");
    if (nivelAgua) nivelAgua.textContent = `${dados.irrigacao.nivelAgua} %`;

    const barra = document.getElementById("barra-agua");
    if (barra) barra.value = Number(dados.irrigacao.nivelAgua) || 0;

    const prox = document.getElementById("proxima-irrigacao");
    if (prox) prox.textContent = `Última/Próxima Irrigação: ${dados.irrigacao.proximaIrrigacao}`;
}

function atualizarEstoque(dados) {
    const dl = document.getElementById("lista-estoque-resumo");
    if (dl && Array.isArray(dados.insumos)) {
        dl.innerHTML = "";
        if (dados.insumos.length === 0) {
            dl.innerHTML = `<div><dt>Nenhum insumo cadastrado</dt><dd>--</dd></div>`;
            return;
        }
        dados.insumos.slice(0, 5).forEach((item) => {
            const div = document.createElement("div");
            const dt = document.createElement("dt");
            dt.textContent = item.nome_ins;
            const dd = document.createElement("dd");
            const span = document.createElement("span");
            span.className = "situacao " + classeSituacao(item.status);
            span.textContent = `${numero(item.estoque, 1)} ${item.unidade}`;
            dd.appendChild(span);
            div.appendChild(dt);
            div.appendChild(dd);
            dl.appendChild(div);
        });
        return;
    }

    if (!dados.estoque) return;
    const fert = document.getElementById("fertilizante");
    if (fert) fert.textContent = dados.estoque.fertilizante;
    const sub = document.getElementById("substrato");
    if (sub) sub.textContent = dados.estoque.substrato;
    const sem = document.getElementById("sementes-tomate");
    if (sem) sem.textContent = dados.estoque.sementesTomate;
}
