
/* ==========================================
   GIE - SISTEMA GLOBAL DE TEMAS
   Modo claro e modo escuro
========================================== */

(() => {

    const CHAVE_TEMA = 'gie-tema';

    // Recupera o tema salvo no navegador
    function obterTema() {
        return localStorage.getItem(CHAVE_TEMA) || 'light';
    }

    // Aplica o tema ao documento
    function aplicarTema(tema, salvar = true) {

        const temaFinal = tema === 'dark' ? 'dark' : 'light';

        document.documentElement.setAttribute(
            'data-theme',
            temaFinal
        );

        if (salvar) {
            localStorage.setItem(CHAVE_TEMA, temaFinal);
        }

        atualizarBotoes(temaFinal);
    }

    // Atualiza os botões de tema
    function atualizarBotoes(tema) {

        const botoes = document.querySelectorAll(
            '[data-theme-toggle]'
        );

        botoes.forEach(botao => {

            if (tema === 'dark') {
                botao.textContent = '☀️ Modo claro';
                botao.setAttribute('aria-label', 'Ativar modo claro');
            } else {
                botao.textContent = '🌙 Modo escuro';
                botao.setAttribute('aria-label', 'Ativar modo escuro');
            }

        });
    }

    // Alterna entre claro e escuro
    function alternarTema() {

        const temaAtual = obterTema();

        const novoTema =
            temaAtual === 'dark' ? 'light' : 'dark';

        aplicarTema(novoTema);
    }

    // Configura os botões encontrados na página
    function configurarBotoes() {

        const botoes = document.querySelectorAll(
            '[data-theme-toggle]'
        );

        botoes.forEach(botao => {

            // Evita adicionar eventos duplicados
            if (botao.dataset.themeConfigurado === 'true') {
                return;
            }

            botao.dataset.themeConfigurado = 'true';

            botao.addEventListener('click', alternarTema);

        });

        atualizarBotoes(obterTema());
    }

    // Aplica o tema imediatamente
    aplicarTema(obterTema(), false);

    // Configura os botões quando o HTML estiver carregado
    if (document.readyState === 'loading') {

        document.addEventListener(
            'DOMContentLoaded',
            configurarBotoes
        );

    } else {

        configurarBotoes();

    }

    // Sincroniza mudanças realizadas em outras abas
    window.addEventListener('storage', (evento) => {

        if (evento.key === CHAVE_TEMA) {

            aplicarTema(
                evento.newValue || 'light',
                false
            );

        }

    });

    // Disponibiliza funções globalmente
    window.GIETema = {
        aplicar: aplicarTema,
        alternar: alternarTema,
        obter: obterTema
    };

})();
