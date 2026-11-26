/**
 * Arquivo: indexes/index_areas.js
 * Objetivo: Tela "Áreas e Culturas". Lê e grava tudo em dashboard_data.php (MySQL).
 */

const API = "dashboard_data.php";

const ROTULOS = {
    agua: { baixa: "Baixa", media: "Média", alta: "Alta" },
    luz: { sol_pleno: "Sol pleno", meia_sombra: "Meia-sombra" },
    nutricao: { baixa: "Baixa", media: "Média", alta: "Alta" }
};

let areas = [];       // [{ id, nome, umidade, umidadeMin, ..., plantas: [] }]
let catalogo = [];    // [{ id, nome, ... }]
let areaAtual = null; // id da área selecionada

const $ = (id) => document.getElementById(id);

function criar(tag, classe, texto) {
    const el = document.createElement(tag);
    if (classe) el.className = classe;
    if (texto !== undefined) el.textContent = texto;
    return el;
}

function formatar(n, casas = 0) {
    return Number(n).toFixed(casas).replace(".", ",");
}

function formatarData(iso) {
    if (!iso) return "--";
    const [ano, mes, dia] = String(iso).slice(0, 10).split("-");
    return `${dia}/${mes}/${ano}`;
}

function hoje() {
    const d = new Date();
    const mes = String(d.getMonth() + 1).padStart(2, "0");
    const dia = String(d.getDate()).padStart(2, "0");
    return `${d.getFullYear()}-${mes}-${dia}`;
}

// Min > max = culturas incompatíveis na mesma área (checado antes da leitura).
function avaliarFaixa(valor, min, max) {
    if (min !== undefined && max !== undefined && min > max) {
        return { texto: "Culturas incompatíveis", classe: "st-alerta" };
    }
    if (valor === null || valor === undefined) return { texto: "Sem leitura", classe: "" };
    if (valor < min) return { texto: "Abaixo do ideal", classe: "st-alerta" };
    if (valor > max) return { texto: "Acima do ideal", classe: "st-alerta" };
    return { texto: "Dentro da faixa", classe: "st-ok" };
}

function preencherStat(id, valor, ideal, status) {
    const box = $(id);
    box.querySelector('[data-role="valor"]').textContent = valor;
    box.querySelector('[data-role="ideal"]').textContent = ideal;
    const badge = box.querySelector('[data-role="status"]');
    badge.textContent = status.texto;
    badge.className = "situacao " + status.classe;
}

// ---------- Comunicação com o servidor ----------

async function pedir(url, opcoes) {
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
    if (!resposta.ok || !corpo || corpo.status !== "sucesso") {
        throw new Error((corpo && corpo.mensagem) || "Não foi possível falar com o servidor.");
    }
    return corpo;
}

function enviar(dados) {
    return pedir(API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(dados)
    });
}

async function carregar() {
    const corpo = await pedir(`${API}?acao=listar_areas`);
    areas = Array.isArray(corpo.areas) ? corpo.areas : [];
    catalogo = Array.isArray(corpo.catalogo) ? corpo.catalogo : [];
    if (!areas.some((a) => a.id === areaAtual)) {
        areaAtual = areas.length > 0 ? areas[0].id : null;
    }
    renderizar();
}

// Executa uma gravação bloqueando o botão enquanto espera.
async function gravar(form, operacao) {
    const botao = form.querySelector('button[type="submit"]');
    botao.disabled = true;
    try {
        await operacao();
    } catch (erro) {
        alert(erro.message);
    } finally {
        botao.disabled = false;
        atualizarBotaoPlantio();
    }
}

// ---------- Tela ----------

function atualizarBotaoPlantio() {
    $("form-plantio").querySelector('button[type="submit"]').disabled =
        catalogo.length === 0 || areaAtual === null;
}

function renderizarSelects() {
    const select = $("select-area");
    select.innerHTML = "";
    areas.forEach((a) => {
        const opt = criar("option", "", a.nome);
        opt.value = a.id;
        opt.selected = a.id === areaAtual;
        select.appendChild(opt);
    });
    select.disabled = areas.length === 0;
    $("btn-remover-area").disabled = areas.length === 0;

    const especies = $("plantio-planta");
    const anterior = especies.value;
    especies.innerHTML = "";
    if (catalogo.length === 0) {
        const opt = criar("option", "", "Cadastre uma espécie primeiro");
        opt.value = "";
        especies.appendChild(opt);
    } else {
        catalogo.forEach((p) => {
            const opt = criar("option", "", p.nome);
            opt.value = p.id;
            especies.appendChild(opt);
        });
        if (anterior) especies.value = anterior;
    }
    $("btn-remover-especie").disabled = catalogo.length === 0;
    atualizarBotaoPlantio();
}

function renderizar() {
    renderizarSelects();
    const area = areas.find((a) => a.id === areaAtual);
    const lista = $("lista-plantas");
    lista.innerHTML = "";

    if (!area) {
        $("titulo-area").textContent = "Nenhuma área cadastrada";
        preencherStat("stat-umidade", "--", "Ideal: --", avaliarFaixa(null));
        preencherStat("stat-ph", "--", "Ideal: --", avaliarFaixa(null));
        $("stat-plantas").querySelector('[data-role="valor"]').textContent = 0;
        $("titulo-plantas").textContent = "Plantas (0)";
        lista.appendChild(criar("div", "vazio", "Crie uma área no formulário \"Nova área\" para começar."));
        return;
    }

    $("titulo-area").textContent = `Área: ${area.nome}`;

    const temUmi = area.umidade !== null && area.umidade !== undefined;
    const temPh = area.ph !== null && area.ph !== undefined;

    preencherStat(
        "stat-umidade",
        temUmi ? `${formatar(area.umidade, 1)}%` : "--",
        area.umidadeMin <= area.umidadeMax
            ? `Ideal: ${formatar(area.umidadeMin, 0)}% a ${formatar(area.umidadeMax, 0)}%`
            : "Ideal: Faixas incompatíveis",
        avaliarFaixa(area.umidade, area.umidadeMin, area.umidadeMax)
    );

    preencherStat(
        "stat-ph",
        temPh ? formatar(area.ph, 2) : "--",
        area.phMin <= area.phMax
            ? `Ideal: ${formatar(area.phMin, 1)} a ${formatar(area.phMax, 1)}`
            : "Ideal: Faixas incompatíveis",
        avaliarFaixa(area.ph, area.phMin, area.phMax)
    );

    $("stat-plantas").querySelector('[data-role="valor"]').textContent = area.plantas.length;
    $("titulo-plantas").textContent = `Plantas (${area.plantas.length})`;

    if (area.plantas.length === 0) {
        lista.appendChild(criar("div", "vazio", "Nenhuma planta nesta área. Use \"Plantar na área\" para registrar um plantio."));
        return;
    }

    area.plantas.forEach((p) => {
        const card = criar("div", "plant-card");

        const header = criar("header");
        header.appendChild(criar("h4", "", p.nome));

        const remover = criar("button", "btn btn-contorno btn-pequeno", "Remover");
        remover.type = "button";
        remover.addEventListener("click", async () => {
            if (!confirm(`Remover ${p.nome} desta área?`)) return;
            remover.disabled = true;
            try {
                await enviar({ acao: "remover_planta", id_area: area.id, id_planta: p.idPlanta });
                await carregar();
            } catch (erro) {
                alert(erro.message);
                remover.disabled = false;
            }
        });
        header.appendChild(remover);
        card.appendChild(header);

        const dl = criar("dl");
        [
            ["Água", ROTULOS.agua[p.agua] || p.agua],
            ["Luz", ROTULOS.luz[p.luz] || p.luz],
            ["Quantidade", p.qtd],
            ["Plantio", formatarData(p.data)],
            ["pH", `${formatar(p.phMin, 1)} - ${formatar(p.phMax, 1)}`],
            ["Nutrição", ROTULOS.nutricao[p.nutricao] || p.nutricao]
        ].forEach(([rotulo, valor]) => {
            dl.appendChild(criar("dt", "", rotulo));
            dl.appendChild(criar("dd", "", String(valor)));
        });
        card.appendChild(dl);

        lista.appendChild(card);
    });
}

// ---------- Eventos ----------

document.addEventListener("DOMContentLoaded", () => {
    $("plantio-data").value = hoje();

    $("select-area").addEventListener("change", (e) => {
        areaAtual = parseInt(e.target.value, 10);
        renderizar();
    });

    // Remover a área selecionada (apaga plantios e sensores dela)
    $("btn-remover-area").addEventListener("click", async (e) => {
        const area = areas.find((a) => a.id === areaAtual);
        if (!area) return;
        if (!confirm(`Remover a área "${area.nome}"? Os plantios e leituras dela também serão apagados do banco.`)) return;
        e.target.disabled = true;
        try {
            await enviar({ acao: "remover_area", id_area: area.id });
            areaAtual = null;
            await carregar();
        } catch (erro) {
            alert(erro.message);
        } finally {
            e.target.disabled = false;
        }
    });

    // Excluir a espécie escolhida do catálogo (só se não estiver plantada)
    $("btn-remover-especie").addEventListener("click", async (e) => {
        const id = parseInt($("plantio-planta").value, 10);
        const especie = catalogo.find((p) => p.id === id);
        if (!especie) return;
        if (!confirm(`Excluir a espécie "${especie.nome}" do catálogo?`)) return;
        e.target.disabled = true;
        try {
            await enviar({ acao: "remover_especie", id_planta: id });
            await carregar();
        } catch (erro) {
            alert(erro.message);
        } finally {
            e.target.disabled = false;
        }
    });

    // Plantar uma espécie do catálogo na área selecionada
    $("form-plantio").addEventListener("submit", (e) => {
        e.preventDefault();
        const f = e.target;
        gravar(f, async () => {
            await enviar({
                acao: "plantio",
                id_area: areaAtual,
                id_planta: parseInt(f.id_planta.value, 10),
                qtd_plantada: parseInt(f.qtd_plantada.value, 10),
                data_plantio: f.data_plantio.value
            });
            f.qtd_plantada.value = "";
            await carregar();
        });
    });

    // Cadastrar espécie no catálogo
    $("form-planta").addEventListener("submit", (e) => {
        e.preventDefault();
        const f = e.target;
        const phMin = parseFloat(f.ph_min.value);
        const phMax = parseFloat(f.ph_max.value);
        if (phMin >= phMax) {
            alert("O pH mínimo deve ser menor que o pH máximo.");
            return;
        }
        gravar(f, async () => {
            await enviar({
                acao: "planta",
                nome: f.nome.value.trim(),
                agua: f.agua.value,
                luz: f.luz.value,
                ph_min: phMin,
                ph_max: phMax,
                nutricao: f.nutricao.value
            });
            f.reset();
            await carregar();
        });
    });

    // Criar área
    $("form-area").addEventListener("submit", (e) => {
        e.preventDefault();
        const f = e.target;
        const umiMin = parseInt(f.umidade_min.value, 10);
        const umiMax = parseInt(f.umidade_max.value, 10);
        const phMin = parseFloat(f.ph_min.value);
        const phMax = parseFloat(f.ph_max.value);
        if (umiMin >= umiMax || phMin >= phMax) {
            alert("Os valores mínimos devem ser menores que os máximos.");
            return;
        }
        gravar(f, async () => {
            const resultado = await enviar({
                acao: "area",
                nome: f.nome.value.trim(),
                area_m2: f.area_m2.value === "" ? null : parseFloat(f.area_m2.value),
                umidade_min: umiMin,
                umidade_max: umiMax,
                ph_min: phMin,
                ph_max: phMax
            });
            areaAtual = resultado.id; // seleciona a área recém-criada
            f.reset();
            await carregar();
        });
    });

    carregar().catch((erro) => {
        $("titulo-area").textContent = "Não foi possível carregar as áreas";
        $("lista-plantas").innerHTML = "";
        $("lista-plantas").appendChild(criar("div", "vazio", erro.message));
    });
});
