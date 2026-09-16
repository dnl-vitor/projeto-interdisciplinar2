// Lista com os caminhos das fotos (podem ser locais ou URLs de banco de imagens)
const imagensPlantas = [

/*
  // --- ESTUFAS E JARDINS BOTÂNICOS ---
    'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1542812596-04a4b4838dec?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1495908333425-29a1e0918c5f?auto=format&fit=crop&w=1920&q=80',
    
    // --- FOLHAGENS E PLANTAS TROPICAIS ---
    'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=1920&q=80',
    
    // --- VASOS, CACTOS E SUCULENTAS ---
    'https://images.unsplash.com/photo-1463936575829-25148e1db1b8?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?auto=format&fit=crop&w=1920&q=80',
    'https://images.unsplash.com/photo-1516481605912-d34c1411504c?auto=format&fit=crop&w=1920&q=80'
*/
    // --- FOTOS LOCAIS ---
    'src/imagens/fundo1.jpg',
    'src/imagens/fundo2.jpg',
    'src/imagens/fundo3.jpg',
    'src/imagens/fundo4.jpg',
    'src/imagens/fundo5.jpg',
    'src/imagens/fundo6.jpg',
    'src/imagens/fundo7.jpg'
  ];
      
      
    function definirFundoAleatorio() {
    // Sorteia um número de 0 até o tamanho do array de imagens
    const indiceAleatorio = Math.floor(Math.random() * imagensPlantas.length);
    const imagemSorteada = imagensPlantas[indiceAleatorio];

    // Aplica a imagem sorteada no background do body
    document.body.style.backgroundImage = `url('${imagemSorteada}')`;
}

// Executa a função automaticamente assim que a página é carregada
window.addEventListener('load', definirFundoAleatorio);