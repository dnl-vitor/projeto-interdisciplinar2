// PROTÓTIPO: os dados vivem só na memória da página (somem ao recarregar).
// Os pontos marcados com "TODO BANCO" são onde entram os fetch() para o PHP/MySQL.

const ROTULOS = {
    agua: { baixa: "Baixa", media: "Média", alta: "Alta" },
    luz: { sol_pleno: "Sol pleno", meia_sombra: "Meia-sombra", sombra: "Sombra" },
    nutricao: { baixa: "Baixa", media: "Média", alta: "Alta" }
};

// TODO BANCO: carregar áreas, leituras e plantas de um endpoint (ex.: listar_areas.php)
const areas = {
    "Canteiro A": {
        umidade: 0, umidadeMin: 0, umidadeMax: 0,
        ph: 0, phMin: 0, phMax: 0,
        plantas: [
            /*{ nome: "", agua: "", luz: "", phMin: 0, phMax: 0, nutricao: "" }*/
        ]
    }
};
let areaAtual = "Canteiro A";

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

function avaliarFaixa(valor, min, max) {
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

function renderizar() {
    const area = areas[areaAtual];

    $("titulo-area").textContent = `Área: ${areaAtual}`;

    // Seletor de áreas
    const select = $("select-area");
    select.innerHTML = "";
    Object.keys(areas).forEach((nome) => {
        const opt = criar("option", "", nome);
        opt.value = nome;
        opt.selected = nome === areaAtual;
        select.appendChild(opt);
    });

    // Leituras
    const temUmi = area.umidade !== null;
    const temPh = area.ph !== null;
    preencherStat(
        "stat-umidade", area.umidade,
        temUmi ? `${formatar(area.umidade, 1)}%` : "--",
        `Ideal: ${area.umidadeMin}% a ${area.umidadeMax}%`,
        avaliarFaixa(area.umidade, area.umidadeMin, area.umidadeMax)
    );
    preencherStat(
        "stat-ph", area.ph,
        temPh ? formatar(area.ph, 2) : "--",
        `Ideal: ${formatar(area.phMin, 1)} a ${formatar(area.phMax, 1)}`,
        avaliarFaixa(area.ph, area.phMin, area.phMax)
    );
    $("stat-plantas").querySelector('[data-role="valor"]').textContent = area.plantas.length;

    // Plantas
    $("titulo-plantas").textContent = `Plantas (${area.plantas.length})`;
    const lista = $("lista-plantas");
    lista.innerHTML = "";

    if (area.plantas.length === 0) {
        lista.appendChild(criar("div", "empty", "Nenhuma planta nesta área. Preencha o formulário \"Adicionar planta\" para começar."));
        return;
    }

    area.plantas.forEach((p, indice) => {
        const card = criar("div", "plant-card");

        const header = criar("header");
        header.appendChild(criar("h4", "", p.nome));
        const remover = criar("button", "btn btn-ghost btn-sm", "Remover");
        remover.type = "button";
        remover.addEventListener("click", () => {
            // TODO BANCO: DELETE da planta (ex.: remover_planta.php)
            area.plantas.splice(indice, 1);
            renderizar();
        });
        header.appendChild(remover);
        card.appendChild(header);

        const dl = criar("dl");
        [
            ["Água", ROTULOS.agua[p.agua]],
            ["Luz", ROTULOS.luz[p.luz]],
            ["pH", `${formatar(p.phMin, 1)} - ${formatar(p.phMax, 1)}`],
            ["Nutrição", ROTULOS.nutricao[p.nutricao]]
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

    $("form-planta").addEventListener("submit", (e) => {
        e.preventDefault();
        const f = e.target;
        const phMin = parseFloat(f.ph_min.value);
        const phMax = parseFloat(f.ph_max.value);

        if (phMin > phMax) {
            alert("O pH mínimo não pode ser maior que o pH máximo.");
            return;
        }

        // TODO BANCO: INSERT da planta ligada à área atual (ex.: salvar_planta.php)
        areas[areaAtual].plantas.push({
            nome: f.nome.value.trim(),
            agua: f.agua.value,
            luz: f.luz.value,
            phMin, phMax,
            nutricao: f.nutricao.value
        });
        f.reset();
        renderizar();
    });

    $("form-area").addEventListener("submit", (e) => {
        e.preventDefault();
        const f = e.target;
        const nome = f.nome.value.trim();

        if (areas[nome]) {
            alert("Já existe uma área com esse nome.");
            return;
        }
        if (parseFloat(f.umidade_min.value) > parseFloat(f.umidade_max.value) ||
            parseFloat(f.ph_min.value) > parseFloat(f.ph_max.value)) {
            alert("Os valores mínimos não podem ser maiores que os máximos.");
            return;
        }

        // TODO BANCO: INSERT da área (ex.: salvar_area.php)
        areas[nome] = {
            umidade: null, umidadeMin: parseInt(f.umidade_min.value), umidadeMax: parseInt(f.umidade_max.value),
            ph: null, phMin: parseFloat(f.ph_min.value), phMax: parseFloat(f.ph_max.value),
            plantas: []
        };
        areaAtual = nome;
        f.reset();
        renderizar();
    });

    renderizar();
});
