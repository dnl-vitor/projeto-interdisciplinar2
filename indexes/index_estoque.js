/**
 * Arquivo: indexes/index_estoque.js
 * Objetivo: Gerenciar a aba "Estoque de Insumos": listagem, reposição (entrada),
 *           consumo (saída por canteiro), cadastro de novos insumos e histórico.
 */

const API = "dashboard_data.php";

const ROTULOS_CAT = {
    fertilizante: "Fertilizante",
    corretivo_ph: "Corretivo de pH",
    outro: "Outro"
};

const ROTULOS_STATUS = {
    ok: { texto: "Normal", classe: "st-ok" },
    baixo: { texto: "Estoque baixo", classe: "st-alerta" },
    zerado: { texto: "Zerado", classe: "st-alerta" }
};

const ROTULOS_MOTIVO = {
    reposicao: "Reposição",
    adubacao: "Adubação",
    correcao_ph: "Correção de pH",
    outro: "Outro"
};

let listaInsumos = [];
let listaAreas = [];

const $ = (id) => document.getElementById(id);

function mostrarMensagem(texto, tipo = "ok") {
    const el = $("msg-estoque");
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

function numero(valor, casas = 2) {
    if (valor === null || valor === undefined || valor === "") return "--";
    return Number(valor).toLocaleString("pt-BR", { minimumFractionDigits: 0, maximumFractionDigits: casas });
}

async function enviar(dados) {
    const resp = await fetch(API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(dados)
    });
    if (resp.status === 401) {
        window.location.href = "index_cardlogin.html";
        throw new Error("Sessão expirada.");
    }
    const res = await resp.json();
    if (!resp.ok || res.status !== "sucesso") {
        throw new Error(res.mensagem || "Falha na operação.");
    }
    return res;
}

async function carregarEstoque() {
    try {
        const resp = await fetch(`${API}?acao=listar_insumos`);
        if (resp.status === 401) {
            window.location.href = "index_cardlogin.html";
            return;
        }
        const res = await resp.json();
        if (!resp.ok || res.status !== "sucesso") {
            throw new Error(res.mensagem || "Erro ao carregar insumos.");
        }

        listaInsumos = res.insumos || [];
        listaAreas = res.areas || [];
        const movs = res.movimentacoes || [];

        const emAlerta = listaInsumos.filter((i) => i.status !== "ok").length;
        $("kpi-total-insumos").textContent = listaInsumos.length;
        $("kpi-alertas-insumos").textContent = emAlerta;
        $("kpi-total-mov").textContent = movs.length;

        $("atualizado-em").textContent = "Atualizado às " + new Date().toLocaleTimeString("pt-BR");

        renderizarTabelaInsumos();
        renderizarSelects();
        renderizarMovimentacoes(movs);
    } catch (erro) {
        console.error(erro);
        mostrarMensagem("Erro ao carregar estoque: " + erro.message, "erro");
    }
}

function renderizarTabelaInsumos() {
    const tbody = $("tbody-insumos");
    tbody.innerHTML = "";

    if (listaInsumos.length === 0) {
        tbody.innerHTML = `<tr><td colspan="6" class="vazio">Nenhum insumo cadastrado ainda.</td></tr>`;
        return;
    }

    listaInsumos.forEach((item) => {
        const st = ROTULOS_STATUS[item.status] || { texto: item.status, classe: "" };
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td><strong>${item.nome_ins}</strong></td>
            <td>${ROTULOS_CAT[item.categoria] || item.categoria}</td>
            <td><strong>${numero(item.estoque)} ${item.unidade}</strong></td>
            <td>${item.lmt_min !== null ? `${numero(item.lmt_min)} ${item.unidade}` : "--"}</td>
            <td>${numero(item.consumo_total)} ${item.unidade}</td>
            <td><span class="situacao ${st.classe}">${st.texto}</span></td>
        `;
        tbody.appendChild(tr);
    });
}

function renderizarSelects() {
    const preencherSelectInsumo = (id) => {
        const sel = $(id);
        const anterior = sel.value;
        sel.innerHTML = "";
        if (listaInsumos.length === 0) {
            const opt = document.createElement("option");
            opt.value = "";
            opt.textContent = "Nenhum insumo cadastrado";
            sel.appendChild(opt);
            sel.disabled = true;
            return;
        }
        sel.disabled = false;
        listaInsumos.forEach((i) => {
            const opt = document.createElement("option");
            opt.value = i.id_insumo;
            opt.textContent = `${i.nome_ins} (${numero(i.estoque)} ${i.unidade})`;
            sel.appendChild(opt);
        });
        if (anterior && listaInsumos.some((i) => String(i.id_insumo) === String(anterior))) {
            sel.value = anterior;
        }
    };

    preencherSelectInsumo("entrada-insumo");
    preencherSelectInsumo("consumo-insumo");

    const selArea = $("consumo-area");
    const areaAnt = selArea.value;
    selArea.innerHTML = "";
    if (listaAreas.length === 0) {
        const opt = document.createElement("option");
        opt.value = "";
        opt.textContent = "Nenhuma área cadastrada";
        selArea.appendChild(opt);
        selArea.disabled = true;
    } else {
        selArea.disabled = false;
        listaAreas.forEach((a) => {
            const opt = document.createElement("option");
            opt.value = a.id_area;
            opt.textContent = a.area_nome;
            selArea.appendChild(opt);
        });
        if (areaAnt && listaAreas.some((a) => String(a.id_area) === String(areaAnt))) {
            selArea.value = areaAnt;
        }
    }
}

function renderizarMovimentacoes(lista) {
    const tbody = $("tbody-movimentacoes");
    tbody.innerHTML = "";

    if (lista.length === 0) {
        tbody.innerHTML = `<tr><td colspan="7" class="vazio">Nenhuma movimentação registrada ainda.</td></tr>`;
        return;
    }

    lista.forEach((m) => {
        const isEntrada = m.tipo === "entrada";
        const sinal = isEntrada ? "+" : "-";
        const classe = isEntrada ? "st-ok" : "st-alerta";
        const labelTipo = isEntrada ? "Entrada" : "Consumo";
        const detalhe = isEntrada
            ? "Reposição"
            : `${m.area_nome || "--"} (${ROTULOS_MOTIVO[m.motivo] || m.motivo})`;

        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td>${formatarDataHora(m.data_hora)}</td>
            <td><span class="situacao ${classe}">${labelTipo}</span></td>
            <td><strong>${m.nome_ins}</strong></td>
            <td>${sinal}${numero(m.quantidade)} ${m.unidade}</td>
            <td>${detalhe}</td>
            <td>${m.observacao || "--"}</td>
            <td>${m.responsavel}</td>
        `;
        tbody.appendChild(tr);
    });
}

document.addEventListener("DOMContentLoaded", () => {
    $("btn-atualizar").addEventListener("click", async () => {
        $("btn-atualizar").disabled = true;
        await carregarEstoque();
        $("btn-atualizar").disabled = false;
    });

    // Entrada de estoque
    $("form-entrada").addEventListener("submit", async (e) => {
        e.preventDefault();
        const f = e.target;
        const btn = f.querySelector('button[type="submit"]');
        btn.disabled = true;
        try {
            await enviar({
                acao: "entrada_insumo",
                id_insumo: Number(f.id_insumo.value),
                quantidade: parseFloat(f.quantidade.value),
                observacao: f.observacao.value.trim()
            });
            mostrarMensagem("Entrada de estoque registrada com sucesso!", "ok");
            f.quantidade.value = "";
            f.observacao.value = "";
            await carregarEstoque();
        } catch (erro) {
            mostrarMensagem("Erro na entrada: " + erro.message, "erro");
        } finally {
            btn.disabled = false;
        }
    });

    // Consumo / Saída de estoque
    $("form-consumo").addEventListener("submit", async (e) => {
        e.preventDefault();
        const f = e.target;
        const btn = f.querySelector('button[type="submit"]');
        btn.disabled = true;
        try {
            await enviar({
                acao: "consumo_insumo",
                id_insumo: Number(f.id_insumo.value),
                id_area: Number(f.id_area.value),
                quantidade: parseFloat(f.quantidade.value),
                motivo: f.motivo.value,
                observacao: f.observacao.value.trim()
            });
            mostrarMensagem("Consumo registrado e abatido do estoque!", "ok");
            f.quantidade.value = "";
            f.observacao.value = "";
            await carregarEstoque();
        } catch (erro) {
            mostrarMensagem("Erro no consumo: " + erro.message, "erro");
        } finally {
            btn.disabled = false;
        }
    });

    // Cadastro de novo insumo
    $("form-novo-insumo").addEventListener("submit", async (e) => {
        e.preventDefault();
        const f = e.target;
        const btn = f.querySelector('button[type="submit"]');
        btn.disabled = true;
        try {
            await enviar({
                acao: "novo_insumo",
                nome_ins: f.nome_ins.value.trim(),
                categoria: f.categoria.value,
                unidade: f.unidade.value,
                estoque_inicial: f.estoque_inicial.value === "" ? 0 : parseFloat(f.estoque_inicial.value),
                lmt_min: f.lmt_min.value === "" ? "" : parseFloat(f.lmt_min.value)
            });
            mostrarMensagem("Novo insumo cadastrado com sucesso!", "ok");
            f.reset();
            await carregarEstoque();
        } catch (erro) {
            mostrarMensagem("Erro ao cadastrar insumo: " + erro.message, "erro");
        } finally {
            btn.disabled = false;
        }
    });

    carregarEstoque();
});
