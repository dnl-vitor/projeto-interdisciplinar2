/**
 * Arquivo: indexes/index_dashboard.js
 * Objetivo: Carregar os indicadores das abas Dashboard, Estoque e Irrigação,
 *           conectando os botões de irrigação e leitura manual ao dashboard_data.php.
 * Cada função só mexe nos elementos que existem na página atual.
 */

const API = "dashboard_data.php";

// Chama a API e devolve o JSON; lança Error com a mensagem do servidor se algo falhar.
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
        // resposta que não é JSON (erro de PHP, página em branco...)
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
    // A página busca o resumo da estufa se tiver qualquer um destes elementos
    // (dashboard, estoque, irrigação e relatórios).
    const temDados = ["areas-ativas", "fertilizante", "status-bomba", "temperatura"]
        .some((id) => document.getElementById(id) !== null);

    if (temDados) {
        carregarDashboard();
        // Atualiza sozinho a cada 10 s, mas só com a aba visível
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

    // Relatórios: imprimir ou salvar em PDF pelo navegador
    const btnImprimir = document.getElementById("btn-imprimir");
    if (btnImprimir) btnImprimir.addEventListener("click", () => window.print());

    // Liga/desliga a bomba de irrigação
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

    // Salvar leitura manual (aba Irrigação & Sensores)
    const btnSalvarLeitura = document.getElementById("btn-salvar-leitura");
    if (btnSalvarLeitura) {
        btnSalvarLeitura.addEventListener("click", async () => {
            const temp    = document.getElementById("input-temp").value;
            const umiAr   = document.getElementById("input-umi-ar").value;
            const umiSolo = document.getElementById("input-umi-solo").value;

            if (!temp || !umiAr || !umiSolo) {
                alert("Por favor, preencha os 3 campos (Temperatura, Umidade do Ar e Umidade do Solo).");
                return;
            }

            try {
                await enviar({
                    acao: "leitura_manual",
                    temperatura: parseFloat(temp),
                    umidade_ar: parseFloat(umiAr),
                    umidade_solo: parseFloat(umiSolo)
                });
                alert("Leitura gravada com sucesso no banco de dados!");
                document.getElementById("input-temp").value = "";
                document.getElementById("input-umi-ar").value = "";
                document.getElementById("input-umi-solo").value = "";

                if (temDados) carregarDashboard();
            } catch (erro) {
                console.error("Erro ao salvar leitura:", erro);
                alert("Erro ao gravar: " + erro.message);
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
            // data-completo: mostra data e hora (relatório); senão só a hora
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

// Classifica o texto de situação da área para escolher a cor do indicador
function classeSituacao(texto) {
    const t = String(texto || "").toUpperCase();
    if (/IDEAL|OK|NORMAL|DENTRO/.test(t)) return "st-ok";
    if (/BAIX|ALT|ACIMA|ABAIXO|CRIT|FORA|ATEN|SECO|ENCHARC/.test(t)) return "st-alerta";
    return "";
}

function numero(valor, casas) {
    if (valor === null || valor === undefined) return "--";
    return Number(valor).toLocaleString("pt-BR", { minimumFractionDigits: casas, maximumFractionDigits: casas });
}

function atualizarAreas(dados) {
    const el = document.getElementById("areas-ativas");
    if (el) {
        // data-numero: mostra só o número (usado nos indicadores do dashboard)
        el.textContent = el.dataset.numero !== undefined ? dados.areasAtivas : `${dados.areasAtivas} Áreas Ativas`;
    }

    const lista = document.getElementById("lista-areas");
    if (!lista || !Array.isArray(dados.areas)) return;
    lista.innerHTML = "";

    // Tabela (dashboard novo): Área | Umidade | pH | Situação
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
                area.umidade === undefined ? "--" : (area.umidade === null ? "--" : numero(area.umidade, 1) + " %"),
                numero(area.ph, 1)
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

    // Lista simples (layout antigo)
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

    // data-dinamico: o botão passa a dizer a ação que vai executar
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
    if (!dados.estoque) return;
    const fert = document.getElementById("fertilizante");
    if (fert) fert.textContent = dados.estoque.fertilizante;

    const sub = document.getElementById("substrato");
    if (sub) sub.textContent = dados.estoque.substrato;

    const sem = document.getElementById("sementes-tomate");
    if (sem) sem.textContent = dados.estoque.sementesTomate;
}
