// PROTÓTIPO: os dados vivem só na memória da página (somem ao recarregar).
// Os pontos marcados com "TODO BANCO" são onde entram os fetch() para o PHP/MySQL.

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
function avaliarFaixa(valor, min, max) {
    if (min > max) return { texto: "Culturas incompatíveis", classe: "badge-warn" };
    if (valor === null || valor === undefined) return { texto: "Sem leitura", classe: "badge-muted" };
    if (valor < min) return { texto: "Abaixo do ideal", classe: "badge-warn" };
    if (valor > max) return { texto: "Acima do ideal", classe: "badge-warn" };
    return { texto: "Dentro da faixa", classe: "badge-ok" };
}

function preencherStat(id, valor, texto, ideal, status) {
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
        select.appendChild(opt);
    });

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
        avaliarFaixa(area.umidade, area.umidadeMin, area.umidadeMax)
    );

    preencherStat(
        "stat-ph",
        area.ph,
        temPh ? formatar(area.ph, 2) : "--",
        textoIdealPh,
        avaliarFaixa(area.ph, area.phMin, area.phMax)
    );

    $("stat-plantas").querySelector('[data-role="valor"]').textContent = area.plantas.length;

    $("titulo-plantas").textContent = `Plantas (${area.plantas.length})`;
    const lista = $("lista-plantas");
    lista.innerHTML = "";

    if (area.plantas.length === 0) {
        lista.appendChild(
            criar("div", "empty", "Nenhuma planta nesta área. Preencha o formulário \"Adicionar planta\" para começar.")
        );
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
        card.appendChild(header);

        const dl = criar("dl");
        [
            ["Água", ROTULOS.agua[p.agua] || p.agua],
            ["Luz", ROTULOS.luz[p.luz] || p.luz],
            ["pH", `${formatar(p.phMin, 1)} - ${formatar(p.phMax, 1)}`],
            ["Nutrição", ROTULOS.nutricao[p.nutricao] || p.nutricao]
        ].forEach(([rotulo, valor]) => {
            dl.appendChild(criar("dt", "", rotulo));
            dl.appendChild(criar("dd", "", valor));
        });
        card.appendChild(dl);

        lista.appendChild(card);
    });
}

document.addEventListener("DOMContentLoaded", () => {
    $("select-area").setAttribute("aria-label", "Área selecionada");

    $("select-area").addEventListener("change", (e) => {
        areaAtual = e.target.value;
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