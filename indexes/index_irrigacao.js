/**
 * Arquivo: indexes/index_irrigacao.js
 * Objetivo: Controlar a aba "Irrigação & Sensores": seletor de canteiro,
 *           indicadores, bomba, leituras manuais, acionamento de irrigação
 *           e históricos de irrigação e sensores.
 */

const API = "dashboard_data.php";

const ROTULOS_SENSOR = {
    ambiente: "Temperatura (°C)",
    umidade: "Umidade do Solo (%)",
    ph_solo: "pH do Solo"
};

let listaAreas = [];
let temperaturaAtual = null;

const $ = (id) => document.getElementById(id);

function mostrarMensagem(texto, tipo = "ok") {
    const el = $("msg-irrigacao");
    if (!el) return;
    el.textContent = texto;
    el.className = "msg-feedback " + (tipo === "erro" ? "erro" : "ok");
    el.hidden = false;
}

function formatarDataHora(iso) {
    if (!iso) return "--";
    const d = new Date(String(iso).replace(" ", "T"));
    return isNaN(d) ? iso : d.toLocaleString("pt-BR");
}

function numero(valor, casas = 1) {
    if (valor === null || valor === undefined || valor === "") return "--";
    return Number(valor).toLocaleString("pt-BR", { minimumFractionDigits: casas, maximumFractionDigits: casas });
}

function atualizarIndicadorCanteiro() {
    const select = $("select-canteiro");
    const area = listaAreas.find((a) => String(a.id_area) === String(select.value));
    const badge = $("badge-canteiro-ativo");

    if (area) {
        const umi = area.umidade !== null ? `${numero(area.umidade, 1)}%` : "--";
        const ph = area.ph_solo !== null ? numero(area.ph_solo, 1) : "--";
        const temp = temperaturaAtual !== null ? `${numero(temperaturaAtual, 1)}°C` : "--";
        badge.textContent = `Canteiro selecionado: ${area.area_nome} · Umidade: ${umi} · pH: ${ph} · Temp. Estufa: ${temp}`;
        badge.className = "situacao " + (area.status_umidade === "ok" && area.status_ph === "ok" ? "st-ok" : "st-alerta");
    } else {
        badge.textContent = "Nenhum canteiro disponível";
        badge.className = "situacao st-alerta";
    }
}

async function carregarDadosIrrigacao() {
    try {
        const resp = await fetch(`${API}?acao=dados_irrigacao`);
        if (resp.status === 401) {
            window.location.href = "index_cardlogin.html";
            return;
        }
        const texto = await resp.text();
        let res;
        try {
            res = JSON.parse(texto);
        } catch {
            throw new Error("Resposta inválida do PHP: " + texto.slice(0, 150));
        }

        if (!resp.ok || res.status !== "sucesso") {
            throw new Error(res.mensagem || "Erro ao carregar dados.");
        }

        listaAreas = res.areas || [];
        temperaturaAtual = res.temperatura_atual ?? null;

        // Indicadores do topo
        $("temperatura").textContent = temperaturaAtual !== null ? `${numero(temperaturaAtual, 1)} °C` : "-- °C";
        $("umidade-solo").textContent = res.umidade_solo_media !== null ? `${numero(res.umidade_solo_media, 1)} %` : "-- %";
        $("nivel-agua-kpi").textContent = `${numero(res.nivel_agua_pct, 1)} %`;

        // Painel da bomba
        const ligada = !!res.bomba_ligada;
        const statusBomba = $("status-bomba");
        statusBomba.textContent = ligada ? "Ligada" : "Desligada";
        statusBomba.dataset.ligada = ligada;

        $("nivel-agua").textContent = `${numero(res.nivel_agua_pct, 1)} % (${numero(res.volume_agua_l, 0)} L)`;
        $("barra-agua").value = Number(res.nivel_agua_pct) || 0;
        $("proxima-irrigacao").textContent = `Última irrigação: ${res.ultima_irrigacao ? formatarDataHora(res.ultima_irrigacao) : "Nenhuma"}`;
        $("btn-irrigacao").textContent = ligada ? "Desligar bomba" : "Ligar bomba";

        // Seletor de canteiro
        const select = $("select-canteiro");
        const valorAnterior = select.value;
        select.innerHTML = "";

        listaAreas.forEach((a, idx) => {
            const opt = document.createElement("option");
            opt.value = a.id_area;
            opt.textContent = a.area_nome;
            if (valorAnterior ? String(a.id_area) === String(valorAnterior) : idx === 0) {
                opt.selected = true;
            }
            select.appendChild(opt);
        });
        select.disabled = listaAreas.length === 0;

        atualizarIndicadorCanteiro();
        renderizarHistoricoIrrigacoes(res.irrigacoes || []);
        renderizarHistoricoLeituras(res.leituras || []);
    } catch (erro) {
        console.error(erro);
        mostrarMensagem("Erro ao carregar dados: " + erro.message, "erro");
        $("badge-canteiro-ativo").textContent = "Erro ao carregar canteiros";
        $("badge-canteiro-ativo").className = "situacao st-alerta";
    }
}

function renderizarHistoricoIrrigacoes(lista) {
    const tbody = $("tbody-hist-irrigacao");
    tbody.innerHTML = "";

    if (lista.length === 0) {
        tbody.innerHTML = `<tr><td colspan="6" class="vazio">Nenhum acionamento registrado ainda.</td></tr>`;
        return;
    }

    lista.forEach((item) => {
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td>${formatarDataHora(item.data_hora)}</td>
            <td><strong>${item.area_nome}</strong></td>
            <td>${item.tipo_acionamento}</td>
            <td>${numero(item.agua_usada_l, 2)} L</td>
            <td>${numero(item.tempo_efetivo_min, 2)} min</td>
            <td>${item.responsavel}</td>
        `;
        tbody.appendChild(tr);
    });
}

function renderizarHistoricoLeituras(lista) {
    const tbody = $("tbody-hist-leituras");
    tbody.innerHTML = "";

    if (lista.length === 0) {
        tbody.innerHTML = `<tr><td colspan="6" class="vazio">Nenhuma leitura registrada ainda.</td></tr>`;
        return;
    }

    lista.forEach((item) => {
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td>${formatarDataHora(item.data_hora)}</td>
            <td><strong>${item.local_sensor}</strong></td>
            <td>${ROTULOS_SENSOR[item.tipo] || item.tipo}</td>
            <td>${numero(item.valor, 2)}</td>
            <td>${item.origem}</td>
            <td>${item.responsavel}</td>
        `;
        tbody.appendChild(tr);
    });
}

document.addEventListener("DOMContentLoaded", () => {
    $("select-canteiro").addEventListener("change", atualizarIndicadorCanteiro);

    $("btn-atualizar").addEventListener("click", async () => {
        $("btn-atualizar").disabled = true;
        await carregarDadosIrrigacao();
        $("btn-atualizar").disabled = false;
    });

    // Ligar / Desligar bomba
    $("btn-irrigacao").addEventListener("click", async () => {
        const btn = $("btn-irrigacao");
        btn.disabled = true;
        try {
            const resp = await fetch(API, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ acao: "toggle_irrigacao" })
            });
            const res = await resp.json();
            if (!resp.ok || res.status !== "sucesso") {
                mostrarMensagem("Erro ao alterar bomba: " + (res.mensagem || "Falha desconhecida."), "erro");
                return;
            }
            mostrarMensagem("Status da bomba atualizado com sucesso.", "ok");
            await carregarDadosIrrigacao();
        } catch (erro) {
            console.error(erro);
            mostrarMensagem("Erro de comunicação com o servidor PHP.", "erro");
        } finally {
            btn.disabled = false;
        }
    });

    // Salvar leitura manual
    $("btn-salvar-leitura").addEventListener("click", async () => {
        const idArea = $("select-canteiro").value;
        const temp = $("input-temp").value.trim();
        const umi = $("input-umi-solo").value.trim();
        const ph = $("input-ph-solo").value.trim();

        if (temp === "" && umi === "" && ph === "") {
            mostrarMensagem("Preencha pelo menos um campo (Temperatura, Umidade ou pH).", "erro");
            return;
        }
        if ((umi !== "" || ph !== "") && !idArea) {
            mostrarMensagem("Selecione um canteiro para atualizar Umidade ou pH.", "erro");
            return;
        }

        const btn = $("btn-salvar-leitura");
        btn.disabled = true;
        try {
            const resp = await fetch(API, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    acao: "leitura_manual",
                    id_area: Number(idArea || 0),
                    temperatura: temp,
                    umidade_solo: umi,
                    ph_solo: ph
                })
            });
            const res = await resp.json();

            if (!resp.ok || res.status !== "sucesso") {
                mostrarMensagem("Erro: " + (res.mensagem || "Não foi possível salvar."), "erro");
                return;
            }

            mostrarMensagem("Leitura manual salva com sucesso no banco de dados!", "ok");
            $("input-temp").value = "";
            $("input-umi-solo").value = "";
            $("input-ph-solo").value = "";
            await carregarDadosIrrigacao();
        } catch (erro) {
            console.error(erro);
            mostrarMensagem("Erro de comunicação com o servidor PHP.", "erro");
        } finally {
            btn.disabled = false;
        }
    });

    // Acionar irrigação no canteiro
    $("btn-acionar-irrigacao").addEventListener("click", async () => {
        const idArea = $("select-canteiro").value;
        const tipo = $("select-tipo-irrigacao").value;
        const minutos = $("input-minutos").value.trim();

        if (!idArea) {
            mostrarMensagem("Selecione um canteiro para irrigar.", "erro");
            return;
        }
        if (tipo === "forcado" && (!minutos || Number(minutos) <= 0)) {
            mostrarMensagem("Na irrigação forçada, informe o tempo em minutos.", "erro");
            return;
        }

        const btn = $("btn-acionar-irrigacao");
        btn.disabled = true;
        try {
            const resp = await fetch(API, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    acao: "acionar_irrigacao",
                    id_area: Number(idArea),
                    tipo: tipo,
                    minutos: minutos
                })
            });
            const res = await resp.json();

            if (!resp.ok || res.status !== "sucesso") {
                mostrarMensagem("Erro ao irrigar: " + (res.mensagem || "Falha desconhecida."), "erro");
                return;
            }

            mostrarMensagem(
                `Irrigação concluída! Água usada: ${numero(res.resultado.litros, 2)} L (${numero(res.resultado.minutos, 2)} min).`,
                "ok"
            );
            $("input-minutos").value = "";
            await carregarDadosIrrigacao();
        } catch (erro) {
            console.error(erro);
            mostrarMensagem("Erro de comunicação com o servidor PHP.", "erro");
        } finally {
            btn.disabled = false;
        }
    });

    carregarDadosIrrigacao();
});
