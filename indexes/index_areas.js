// Aba "Áreas e Culturas": lê de listar_areas.php e grava em dashboard_data.php.
// Os arquivos .php precisam estar na mesma pasta deste HTML.
const API_LISTAR = "listar_areas.php";
const API_GRAVAR = "dashboard_data.php";

/**
 * Arquivo: indexes/index_areas.js
 * Objetivo: Gerenciar a tela "Áreas e Culturas", mantendo os dados sincronizados
 *           com o banco de dados MySQL através de dashboard_data.php.
 */

const ROTULOS = {
    agua: { baixa: "Baixa", media: "Média", alta: "Alta" },
    luz: { sol_pleno: "Sol pleno", meia_sombra: "Meia-sombra", sombra: "Sombra" },
    nutricao: { baixa: "Baixa", media: "Média", alta: "Alta" }
};

let areas = {};
let areaAtual = "";
let areas = [];
let catalogo = [];
let areaAtual = null; // id_area da área selecionada

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

/**
 * CORREÇÃO: Verifica primeiro se min > max (culturas incompatíveis na mesma área),
 * mesmo que o sensor ainda não possua leitura (valor === null).
 */
=======
function formatarData(iso) {
    const [ano, mes, dia] = iso.split("-");
    return `${dia}/${mes}/${ano}`;
}

function hoje() {
    const d = new Date();
    const mes = String(d.getMonth() + 1).padStart(2, "0");
    const dia = String(d.getDate()).padStart(2, "0");
    return `${d.getFullYear()}-${mes}-${dia}`;
}

function avaliarFaixa(valor, min, max) {
    if (min > max) return { texto: "Culturas incompatíveis", classe: "badge-warn" };
    if (valor === null || valor === undefined) return { texto: "Sem leitura", classe: "badge-muted" };
    if (valor < min) return { texto: "Abaixo do ideal", classe: "badge-warn" };
    if (valor > max) return { texto: "Acima do ideal", classe: "badge-warn" };
    return { texto: "Dentro da faixa", classe: "badge-ok" };
}

function preencherStat(id, texto, ideal, status) {
    const box = $(id);
    box.querySelector('[data-role="valor"]').textContent = texto;
    box.querySelector('[data-role="ideal"]').textContent = ideal;
    const badge = box.querySelector('[data-role="status"]');
    badge.textContent = status.texto;
    badge.className = "badge " + status.classe;
}

/**
 * Carrega áreas, leituras de sensores e plantas do MySQL
 */
async function carregarDoBanco(manterAreaSelecionada = true) {
    try {
        const resposta = await fetch("dashboard_data.php?acao=listar_areas");
        const resultado = await resposta.json();

        if (!resposta.ok || resultado.status !== "sucesso") {
            throw new Error(resultado.mensagem || "Erro ao buscar áreas do banco.");
        }

        areas = resultado.areas || {};
        const nomesAreas = Object.keys(areas);

        if (!manterAreaSelecionada || !areaAtual || !areas[areaAtual]) {
            areaAtual = nomesAreas.length > 0 ? nomesAreas[0] : "";
        }

        renderizar();
    } catch (erro) {
        console.error("Falha ao carregar dados do banco:", erro);
        alert("Não foi possível carregar os dados do banco: " + erro.message);
    }
}

/**
 * Atualiza a interface gráfica com os dados da área selecionada
 */
function renderizar() {
    const nomesAreas = Object.keys(areas);
    const select = $("select-area");
    select.innerHTML = "";

    if (nomesAreas.length === 0) {
        $("titulo-area").textContent = "Nenhuma área cadastrada";
        $("lista-plantas").innerHTML = "";
        $("lista-plantas").appendChild(
            criar("div", "empty", "Crie uma área no formulário \"Nova área\" ao lado para começar.")
        );
        return;
    }

    const area = areas[areaAtual];
    $("titulo-area").textContent = `Área: ${areaAtual}`;

    nomesAreas.forEach((nome) => {
        const opt = criar("option", "", nome);
        opt.value = nome;
        opt.selected = nome === areaAtual;
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
    return pedir(API_GRAVAR, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(dados)
    });
}

async function carregar() {
    const corpo = await pedir(API_LISTAR);
    areas = corpo.areas;
    catalogo = corpo.catalogo;
    if (!areas.some((a) => a.id === areaAtual)) {
        areaAtual = areas.length > 0 ? areas[0].id : null;
    }
    renderizar();
}

// Executa uma operação de gravação, bloqueando o botão enquanto espera.
async function gravar(form, operacao) {
    const botao = form.querySelector('button[type="submit"]');
    botao.disabled = true;
    try {
        await operacao();
    } catch (erro) {
        alert(erro.message);
    } finally {
        botao.disabled = false;
    }
}

// ---------- Tela ----------

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

    const especies = $("plantio-planta");
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
    }
    $("form-plantio").querySelector('button[type="submit"]').disabled =
        catalogo.length === 0 || areaAtual === null;
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
        lista.appendChild(criar("div", "empty", "Crie uma área no formulário \"Nova área\" para começar."));
        return;
    }

    $("titulo-area").textContent = `Área: ${area.nome}`;

    const temUmi = area.umidade !== null && area.umidade !== undefined;
    const temPh = area.ph !== null && area.ph !== undefined;

    const textoIdealUmi = area.umidadeMin <= area.umidadeMax
        ? `Ideal: ${formatar(area.umidadeMin, 0)}% a ${formatar(area.umidadeMax, 0)}%`
        : "Ideal: Faixas incompatíveis";

    const textoIdealPh = area.phMin <= area.phMax
        ? `Ideal: ${formatar(area.phMin, 1)} a ${formatar(area.phMax, 1)}`
        : "Ideal: Faixas incompatíveis";

    preencherStat(
        "stat-umidade",
        area.umidade,
        temUmi ? `${formatar(area.umidade, 1)}%` : "--",
        textoIdealUmi,
    preencherStat(
        "stat-umidade",
        area.umidade !== null ? `${formatar(area.umidade, 1)}%` : "--",
        `Ideal: ${area.umidadeMin}% a ${area.umidadeMax}%`,
        avaliarFaixa(area.umidade, area.umidadeMin, area.umidadeMax)
    );

    preencherStat(
        "stat-ph",
        area.ph,
        temPh ? formatar(area.ph, 2) : "--",
        textoIdealPh,
        area.ph !== null ? formatar(area.ph, 2) : "--",
        `Ideal: ${formatar(area.phMin, 1)} a ${formatar(area.phMax, 1)}`,
        avaliarFaixa(area.ph, area.phMin, area.phMax)
    );

    $("stat-plantas").querySelector('[data-role="valor"]').textContent = area.plantas.length;

    $("titulo-plantas").textContent = `Plantas (${area.plantas.length})`;

    if (area.plantas.length === 0) {
        lista.appendChild(
            criar("div", "empty", "Nenhuma planta nesta área. Preencha o formulário \"Adicionar planta\" para começar.")
        );
        lista.appendChild(criar("div", "empty", "Nenhuma planta nesta área. Use \"Plantar na área\" para registrar um plantio."));
        return;
    }

    area.plantas.forEach((p) => {
        const card = criar("div", "plant-card");

        const header = criar("header");
        header.appendChild(criar("h4", "", p.nome));

        const remover = criar("button", "btn btn-ghost btn-sm", "Remover");
        remover.type = "button";
        remover.addEventListener("click", async () => {
            try {
                const resp = await fetch("dashboard_data.php", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        acao: "remover_planta",
                        id_area: area.id_area,
                        id_planta: p.id_planta
                    })
                });
                const res = await resp.json();
                if (!resp.ok || res.status !== "sucesso") {
                    alert(res.mensagem || "Erro ao remover planta.");
                    return;
                }
                await carregarDoBanco(true);
            } catch (err) {
                console.error("Erro ao remover planta:", err);
                alert("Erro de conexão ao remover a planta.");
            }
        });

        header.appendChild(remover);
        const encerrar = criar("button", "btn btn-ghost btn-sm", "Encerrar");
        encerrar.type = "button";
        encerrar.addEventListener("click", async () => {
            if (!confirm(`Encerrar o plantio de ${p.nome}? Ele sai da lista e fica no histórico.`)) return;
            encerrar.disabled = true;
            try {
                await enviar({ acao: "encerrar_plantio", id_plantio: p.idPlantio });
                await carregar();
            } catch (erro) {
                alert(erro.message);
                encerrar.disabled = false;
            }
        });
        header.appendChild(encerrar);
        card.appendChild(header);

        const dl = criar("dl");
        [
            ["Água", ROTULOS.agua[p.agua] || p.agua],
            ["Luz", ROTULOS.luz[p.luz] || p.luz],
            ["Quantidade", p.qtd],
            ["Plantio", formatarData(p.data)],
            ["Água", ROTULOS.agua[p.agua]],
            ["Luz", ROTULOS.luz[p.luz]],
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

    $("form-planta").addEventListener("submit", async (e) => {
        e.preventDefault();
        const f = e.target;
        const phMin = parseFloat(f.ph_min.value);
        const phMax = parseFloat(f.ph_max.value);

        if (phMin >= phMax) {
            alert("O pH mínimo deve ser menor que o pH máximo.");
            return;
        }

        if (!areaAtual) {
            alert("Crie ou selecione uma área antes de adicionar uma planta.");
            return;
        }

        try {
            const resposta = await fetch("dashboard_data.php", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    acao: "planta",
                    area_nome: areaAtual,
                    nome: f.nome.value.trim(),
                    agua: f.agua.value,
                    luz: f.luz.value,
                    ph_min: phMin,
                    ph_max: phMax,
                    nutricao: f.nutricao.value
                })
            });

            const resultado = await resposta.json();
            if (!resposta.ok || resultado.status !== "sucesso") {
                alert(resultado.mensagem || "Erro ao salvar a planta.");
                return;
            }

            f.reset();
            await carregarDoBanco(true);
        } catch (erro) {
            console.error("Erro ao salvar planta:", erro);
            alert("Erro de comunicação com o servidor PHP.");
        }
    $("form-plantio").addEventListener("submit", (e) => {
        e.preventDefault();
        const f = e.target;
        gravar(f, async () => {
            await enviar({
                acao: "plantio",
                id_area: areaAtual,
                id_planta: f.id_planta.value,
                qtd_plantada: f.qtd_plantada.value,
                data_plantio: f.data_plantio.value
            });
            f.qtd_plantada.value = "";
            await carregar();
        });
    });

    $("form-planta").addEventListener("submit", (e) => {
        e.preventDefault();
        const f = e.target;
        gravar(f, async () => {
            await enviar({
                acao: "planta",
                nome: f.nome.value,
                agua: f.agua.value,
                luz: f.luz.value,
                ph_min: f.ph_min.value,
                ph_max: f.ph_max.value,
                nutricao: f.nutricao.value
            });
            f.reset();
            await carregar();
        });
    });

    $("form-area").addEventListener("submit", async (e) => {
        e.preventDefault();
        const f = e.target;
        const nome = f.nome.value.trim();
        const umiMin = parseInt(f.umidade_min.value, 10);
        const umiMax = parseInt(f.umidade_max.value, 10);
        const phMin = parseFloat(f.ph_min.value);
        const phMax = parseFloat(f.ph_max.value);

        if (umiMin >= umiMax || phMin >= phMax) {
            alert("Os valores mínimos devem ser menores que os máximos.");
            return;
        }

        try {
            const resposta = await fetch("dashboard_data.php", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    acao: "area",
                    nome: nome,
                    umidade_min: umiMin,
                    umidade_max: umiMax,
                    ph_min: phMin,
                    ph_max: phMax
                })
            });

            const resultado = await resposta.json();
            if (!resposta.ok || resultado.status !== "sucesso") {
                alert(resultado.mensagem || "Erro ao criar a área.");
                return;
            }

            areaAtual = nome;
            f.reset();
            await carregarDoBanco(true);
        } catch (erro) {
            console.error("Erro ao criar área:", erro);
            alert("Erro de comunicação com o servidor PHP.");
        }
    });

    carregarDoBanco(false);
});
        gravar(f, async () => {
            const resultado = await enviar({
                acao: "area",
                nome: f.nome.value,
                area_m2: f.area_m2.value,
                umidade_min: f.umidade_min.value,
                umidade_max: f.umidade_max.value,
                ph_min: f.ph_min.value,
                ph_max: f.ph_max.value
            });
            areaAtual = resultado.id; // já seleciona a área recém-criada
            f.reset();
            await carregar();
        });
    });

    carregar().catch((erro) => {
        $("titulo-area").textContent = "Não foi possível carregar as áreas";
        $("lista-plantas").appendChild(criar("div", "empty", erro.message));
    });
});
