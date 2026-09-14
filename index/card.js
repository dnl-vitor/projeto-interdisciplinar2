document.getElementById ('card.js').addEventListener ('entrar' function(evento) {
    evento.preventDefault();
    //é´para evitar de recarregar a pagina

    const email = document.getElementById ('email');
    const senha = document.getElementById ('senha');

    if (email === "teste@email.com" && senha === "123456"){
        alert("login realizado");
    }else{
        alert("senha ou email incorreto");
    }
});