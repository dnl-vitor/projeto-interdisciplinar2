
const imagensPlantas = [
    {
        imagem: 'src/imagens/fundo1.jpg',
    },
    {
        imagem: 'src/imagens/fundo2.jpg',
    },
    {
        imagem: 'src/imagens/fundo3.jpg',
        cor: '#ffffff'
    },
    {
        imagem: 'src/imagens/fundo4.jpg',
    },
    {
        imagem: 'src/imagens/fundo5.jpg',
        cor: '#ffffff'
    }
];

function definirFundoAleatorio() {

    // Sorteia um número de 0 até o tamanho do array de imagens
    const indiceAleatorio =
        Math.floor(Math.random() * imagensPlantas.length);

    const imagemSorteada =
        imagensPlantas[indiceAleatorio]; // saida aleatoria

    // Define o fundo/ sorteia o fundo 
    document.body.style.backgroundImage =
        `url('${imagemSorteada.imagem}')`;

    // Define a cor do h1
    document.querySelector('h1').style.color =
        imagemSorteada.cor;
}

window.addEventListener('load', definirFundoAleatorio);
