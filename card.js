document.getElementById('meu-formulario').addEventListener('submit', function(evento) {
    evento.preventDefault();
    // é para evitar de recarregar a pagina

    const email = document.getElementById('email').value;
    const senha = document.getElementById('senha').value;

    if (email === "teste@email.com" && senha === "123456"){
        
        // Redireciona o usuário para a página do dashboard
        location.href = "index_dashbord.html"; 
        
    } else {
        alert("senha ou email incorreto");
    }
});