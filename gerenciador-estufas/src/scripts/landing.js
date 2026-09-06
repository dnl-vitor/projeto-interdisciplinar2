/* =========================================================
   LANDING PAGE — interações
   Sem framework: este arquivo cobre navegação, FAQ e o
   comportamento simulado dos formulários (não há backend
   real conectado nesta etapa do projeto).
   ========================================================= */

(function () {
  'use strict';

  /* ---- Menu mobile ---- */
  var navToggle = document.getElementById('navToggle');
  var navLinks = document.getElementById('navLinks');

  if (navToggle && navLinks) {
    navToggle.addEventListener('click', function () {
      var isOpen = navLinks.classList.toggle('open');
      navToggle.setAttribute('aria-expanded', String(isOpen));
    });

    navLinks.querySelectorAll('a').forEach(function (link) {
      link.addEventListener('click', function () {
        navLinks.classList.remove('open');
        navToggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  /* ---- Destaca o link do menu conforme a seção visível ---- */
  var sections = document.querySelectorAll('main section[id]');
  var linkMap = {};
  document.querySelectorAll('.nav-links a').forEach(function (link) {
    linkMap[link.getAttribute('href').replace('#', '')] = link;
  });

  if ('IntersectionObserver' in window && sections.length) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        var link = linkMap[entry.target.id];
        if (!link) return;
        if (entry.isIntersecting) {
          document.querySelectorAll('.nav-links a').forEach(function (l) { l.classList.remove('active'); });
          link.classList.add('active');
        }
      });
    }, { rootMargin: '-45% 0px -50% 0px' });

    sections.forEach(function (section) { observer.observe(section); });
  }

  /* ---- FAQ accordion ---- */
  document.querySelectorAll('.faq-item').forEach(function (item) {
    var question = item.querySelector('.faq-question');
    var answer = item.querySelector('.faq-answer');

    question.addEventListener('click', function () {
      var isOpen = item.getAttribute('data-open') === 'true';

      // fecha os outros itens abertos
      document.querySelectorAll('.faq-item[data-open="true"]').forEach(function (other) {
        if (other !== item) {
          other.setAttribute('data-open', 'false');
          other.querySelector('.faq-question').setAttribute('aria-expanded', 'false');
          other.querySelector('.faq-answer').style.maxHeight = null;
        }
      });

      item.setAttribute('data-open', String(!isOpen));
      question.setAttribute('aria-expanded', String(!isOpen));
      answer.style.maxHeight = !isOpen ? answer.scrollHeight + 'px' : null;
    });
  });

  /* ---- Utilitário: exibe mensagem de status de um formulário ---- */
  function showStatus(el, message, type) {
    el.textContent = message;
    el.className = 'form-status visible ' + type;
  }

  /* ---- Formulário de cadastro (simulado) ----
     Nesta etapa do projeto não há backend conectado: o
     envio é simulado para validar o fluxo da interface. */
  var cadastroForm = document.getElementById('cadastroForm');
  if (cadastroForm) {
    cadastroForm.addEventListener('submit', function (event) {
      event.preventDefault();
      if (!cadastroForm.checkValidity()) {
        cadastroForm.reportValidity();
        return;
      }
      var nome = document.getElementById('empresaNome').value;
      showStatus(
        document.getElementById('cadastroStatus'),
        'Cadastro de "' + nome + '" recebido. Em breve nossa equipe entra em contato para concluir a aprovação.',
        'success'
      );
      cadastroForm.reset();
    });
  }

  /* ---- Formulário de contato (simulado) ---- */
  var contatoForm = document.getElementById('contatoForm');
  if (contatoForm) {
    contatoForm.addEventListener('submit', function (event) {
      event.preventDefault();
      if (!contatoForm.checkValidity()) {
        contatoForm.reportValidity();
        return;
      }
      showStatus(
        document.getElementById('contatoStatus'),
        'Mensagem enviada. Respondemos em até 1 dia útil.',
        'success'
      );
      contatoForm.reset();
    });
  }

  /* ---- Botão de download (simulado) ----
     Não há instalador real nesta etapa; o botão apenas
     confirma a intenção e sugere a alternativa web. */
  var downloadBtn = document.getElementById('downloadBtn');
  if (downloadBtn) {
    downloadBtn.addEventListener('click', function () {
      downloadBtn.textContent = 'Preparando download…';
      downloadBtn.disabled = true;
      setTimeout(function () {
        downloadBtn.textContent = 'Instalador disponível após aprovação';
        downloadBtn.disabled = true;
      }, 900);
    });
  }

})();
