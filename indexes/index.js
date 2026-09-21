document.addEventListener("DOMContentLoaded", () => {

    // Carrega assim que a página abrir
    carregarDashboard();

    // Atualiza automaticamente a cada 10 segundos
    setInterval(carregarDashboard, 10000);

});


async function carregarDashboard() {

    try {

        const resposta =
            await fetch("/api/dashboard");

        if (!resposta.ok) {
            throw new Error(
                "Não foi possível carregar o dashboard"
            );
        }

        const dados =
            await resposta.json();


        atualizarAreas(dados);

        atualizarSensores(dados);

        atualizarIrrigacao(dados);

        atualizarEstoque(dados);


    } catch (erro) {

        console.error(
            "Erro ao carregar dashboard:",
            erro
        );

    }

}


function atualizarAreas(dados) {

    document.getElementById("areas-ativas")
        .textContent =
        `${dados.areasAtivas} Áreas Ativas`;


    const lista =
        document.getElementById("lista-areas");

    lista.innerHTML = "";


    dados.areas.forEach(area => {

        const li =
            document.createElement("li");

        li.textContent =
            `${area.nome} - ${area.status}`;

        lista.appendChild(li);

    });

}


function atualizarSensores(dados) {

    document.getElementById("temperatura")
        .textContent =
        `${dados.sensores.temperatura} °C`;


    document.getElementById("umidade-ar")
        .textContent =
        `${dados.sensores.umidadeAr} %`;


    document.getElementById("umidade-solo")
        .textContent =
        `${dados.sensores.umidadeSolo} %`;

}


function atualizarIrrigacao(dados) {

    const statusBomba =
        document.getElementById("status-bomba");


    statusBomba.textContent =
        dados.irrigacao.bombaLigada
            ? "Ligada"
            : "Desligada";


    document.getElementById("nivel-agua")
        .textContent =
        `${dados.irrigacao.nivelAgua} %`;


    document.getElementById("proxima-irrigacao")
        .textContent =
        `Próxima Irrigação: ${
            dados.irrigacao.proximaIrrigacao
        }`;

}


function atualizarEstoque(dados) {

    document.getElementById("fertilizante")
        .textContent =
        dados.estoque.fertilizante;


    document.getElementById("substrato")
        .textContent =
        dados.estoque.substrato;


    document.getElementById("sementes-tomate")
        .textContent =
        dados.estoque.sementesTomate;

}
document
    .getElementById("btn-irrigacao")
    .addEventListener("click", async () => {

        try {

            const resposta =
                await fetch("/api/irrigacao/toggle", {
                    method: "POST"
                });

            if (!resposta.ok) {
                throw new Error(
                    "Erro ao controlar irrigação"
                );
            }

            // Atualiza o dashboard
            await carregarDashboard();

        } catch (erro) {

            console.error(erro);

            alert(
                "Não foi possível controlar a irrigação."
            );

        }

    });
