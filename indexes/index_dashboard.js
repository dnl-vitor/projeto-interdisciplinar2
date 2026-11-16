/**
 * Arquivo: indexes/index_dashboard.js
 * Objetivo: Carregar os indicadores das abas Dashboard, Estoque e Irrigação,
 *           conectando os botões de irrigação e leitura manual ao dashboard_data.php.
 */

document.addEventListener("DOMContentLoaded", () => {
    const isDashboard = document.getElementById("areas-ativas") !== null;
    const isEstoque   = document.getElementById("fertilizante") !== null;

    if (isDashboard || isEstoque) {
        carregarDashboard();
        setInterval(carregarDashboard, 10000);
    }

    // CORREÇÃO: Botão de ligar/desligar irrigação apontando para dashboard_data.php
    const btnIrrigacao = document.getElementById("btn-irrigacao");
    if (btnIrrigacao) {
        btnIrrigacao.addEventListener("click", async () => {
            try {
                const resposta = await fetch("dashboard_data.php", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ acao: "toggle_irrigacao" })
                });
                const resultado = await resposta.json();
                if (!resposta.ok || resultado.status !== "sucesso") {
                    throw new Error(resultado.mensagem || "Erro ao controlar irrigação");
                }
                await carregarDashboard();
            } catch (erro) {
                console.error(erro);
                alert("Não foi possível controlar a irrigação: " + erro.message);
            }
        });
    }

    // CORREÇÃO: Botão de salvar leitura manual apontando para dashboard_data.php
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
                const resposta = await fetch("dashboard_data.php", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        acao: "leitura_manual",
                        temperatura: parseFloat(temp),
                        umidade_ar: parseFloat(umiAr),
                        umidade_solo: parseFloat(umiSolo)
                    })
                });

                const resultado = await resposta.json();

                if (resposta.ok && resultado.status === "sucesso") {
                    alert("Leitura gravada com sucesso no banco de dados!");
                    document.getElementById("input-temp").value = "";
                    document.getElementById("input-umi-ar").value = "";
                    document.getElementById("input-umi-solo").value = "";

                    if (isDashboard) carregarDashboard();
                } else {
                    alert("Erro ao gravar: " + (resultado.mensagem || "Falha desconhecida."));
                }
            } catch (erro) {
                console.error("Erro ao salvar leitura:", erro);
                alert("Erro ao tentar conectar com o servidor PHP.");
            }
        });
    }
});

async function carregarDashboard() {
    try {
        const resposta = await fetch("dashboard_data.php?acao=resumo_dashboard");
        if (!resposta.ok) throw new Error("Não foi possível carregar o dashboard");
        const dados = await resposta.json();

        atualizarAreas(dados);
        atualizarSensores(dados);
        atualizarIrrigacao(dados);
        atualizarEstoque(dados);
    } catch (erro) {
        console.error("Erro ao carregar dashboard:", erro);
    }
}

function atualizarAreas(dados) {
    const el = document.getElementById("areas-ativas");
    if (el) el.textContent = `${dados.areasAtivas} Áreas Ativas`;

    const lista = document.getElementById("lista-areas");
    if (lista && Array.isArray(dados.areas)) {
        lista.innerHTML = "";
        dados.areas.forEach((area) => {
            const li = document.createElement("li");
            li.textContent = `${area.nome} - ${area.status}`;
            lista.appendChild(li);
        });
    }
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
    const statusBomba = document.getElementById("status-bomba");
    if (statusBomba) statusBomba.textContent = dados.irrigacao.bombaLigada ? "Ligada" : "Desligada";

    const nivelAgua = document.getElementById("nivel-agua");
    if (nivelAgua) nivelAgua.textContent = `${dados.irrigacao.nivelAgua} %`;

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