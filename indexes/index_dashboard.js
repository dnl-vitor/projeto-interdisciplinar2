document.addEventListener("DOMContentLoaded", () => {
    
    // Verifica se estamos na página principal do Dashboard (procurando um elemento chave)
    const isDashboard = document.getElementById("areas-ativas") !== null;

    if (isDashboard) {
        carregarDashboard();
        setInterval(carregarDashboard, 10000);
    }

    // Botão de irrigação (Só existe no Dashboard)
    const btnIrrigacao = document.getElementById("btn-irrigacao");
    if (btnIrrigacao) {
        btnIrrigacao.addEventListener("click", async () => {
            try {
                const resposta = await fetch("/api/irrigacao/toggle", { method: "POST" });
                if (!resposta.ok) throw new Error("Erro ao controlar irrigação");
                await carregarDashboard();
            } catch (erro) {
                console.error(erro);
                alert("Não foi possível controlar a irrigação.");
            }
        });
    }

    // Botão de salvar leitura manual (Só existe na página de Irrigação & Sensores)
    const btnSalvarLeitura = document.getElementById("btn-salvar-leitura");
    if (btnSalvarLeitura) {
        btnSalvarLeitura.addEventListener("click", async () => {
            const temp = document.getElementById("input-temp").value;
            const umiAr = document.getElementById("input-umi-ar").value;
            const umiSolo = document.getElementById("input-umi-solo").value;

            if (!temp || !umiAr || !umiSolo) {
                alert("Por favor, preencha os 3 campos (Temperatura, Umidade do Ar e Umidade do Solo).");
                return;
            }

            try {
                const resposta = await fetch("inserir_leitura_manual.php", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        temperatura: parseFloat(temp),
                        umidade: parseInt(umiAr),
                        luminosidade: parseInt(umiSolo)
                    })
                });

                const resultado = await resposta.json();

                if (resposta.ok && resultado.status === "sucesso") {
                    alert("Leitura gravada com sucesso no banco de dados!");
                    document.getElementById("input-temp").value = "";
                    document.getElementById("input-umi-ar").value = "";
                    document.getElementById("input-umi-solo").value = "";
                    
                    if(isDashboard) carregarDashboard();
                } else {
                    alert("Erro ao gravar: " + resultado.mensagem);
                }

            } catch (erro) {
                console.error("Erro ao salvar leitura:", erro);
                alert("Erro ao tentar conectar com o servidor. Verifique se o PHP está a rodar.");
            }
        });
    }
});

async function carregarDashboard() {
    try {
        const resposta = await fetch("/api/dashboard");
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
    if(el) el.textContent = `${dados.areasAtivas} Áreas Ativas`;
    
    const lista = document.getElementById("lista-areas");
    if(lista) {
        lista.innerHTML = "";
        dados.areas.forEach(area => {
            const li = document.createElement("li");
            li.textContent = `${area.nome} - ${area.status}`;
            lista.appendChild(li);
        });
    }
}

function atualizarSensores(dados) {
    const temp = document.getElementById("temperatura");
    if(temp) temp.textContent = `${dados.sensores.temperatura} °C`;
    
    const umiAr = document.getElementById("umidade-ar");
    if(umiAr) umiAr.textContent = `${dados.sensores.umidadeAr} %`;
    
    const umiSolo = document.getElementById("umidade-solo");
    if(umiSolo) umiSolo.textContent = `${dados.sensores.umidadeSolo} %`;
}

function atualizarIrrigacao(dados) {
    const statusBomba = document.getElementById("status-bomba");
    if(statusBomba) statusBomba.textContent = dados.irrigacao.bombaLigada ? "Ligada" : "Desligada";
    
    const nivelAgua = document.getElementById("nivel-agua");
    if(nivelAgua) nivelAgua.textContent = `${dados.irrigacao.nivelAgua} %`;
    
    const prox = document.getElementById("proxima-irrigacao");
    if(prox) prox.textContent = `Próxima Irrigação: ${dados.irrigacao.proximaIrrigacao}`;
}

function atualizarEstoque(dados) {
    const fert = document.getElementById("fertilizante");
    if(fert) fert.textContent = dados.estoque.fertilizante;
    
    const sub = document.getElementById("substrato");
    if(sub) sub.textContent = dados.estoque.substrato;
    
    const sem = document.getElementById("sementes-tomate");
    if(sem) sem.textContent = dados.estoque.sementesTomate;
}
