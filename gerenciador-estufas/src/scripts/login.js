/* =========================================================
   LOGIN — validação e simulação de autenticação
   Nesta etapa do projeto não existe backend conectado.
   O formulário valida os campos e grava uma sessão local
   apenas para permitir testar o Dashboard (próxima etapa)
   com cada um dos 3 perfis de acesso.
   ========================================================= */

(function () {
  'use strict';

  var form = document.getElementById('loginForm');
  var statusEl = document.getElementById('loginStatus');
  var submitBtn = document.getElementById('loginSubmit');
  var toggleSenha = document.getElementById('toggleSenha');
  var senhaInput = document.getElementById('loginSenha');
  var perfilSelect = document.getElementById('perfilDemo');

  /* ---- Mostrar/ocultar senha ---- */
  if (toggleSenha && senhaInput) {
    toggleSenha.addEventListener('click', function () {
      var isPassword = senhaInput.getAttribute('type') === 'password';
      senhaInput.setAttribute('type', isPassword ? 'text' : 'password');
      toggleSenha.textContent = isPassword ? 'ocultar' : 'mostrar';
    });
  }

  function showStatus(message, type) {
    statusEl.textContent = message;
    statusEl.className = 'form-status visible ' + type;
  }

  if (form) {
    form.addEventListener('submit', function (event) {
      event.preventDefault();

      if (!form.checkValidity()) {
        form.reportValidity();
        return;
      }

      var email = document.getElementById('loginEmail').value.trim();
      var perfil = perfilSelect ? perfilSelect.value : 'produtor';

      submitBtn.disabled = true;
      submitBtn.textContent = 'Entrando…';

      // Simula uma checagem de credenciais. Quando o backend
      // existir, este trecho vira uma chamada real de autenticação.
      setTimeout(function () {
        var sessao = {
          email: email,
          perfil: perfil,
          logadoEm: new Date().toISOString()
        };
        window.localStorage.setItem('gie_sessao', JSON.stringify(sessao));

        showStatus('Login confirmado. Redirecionando para o Dashboard…', 'success');
        setTimeout(function () {
          window.location.href = 'dashboard.html';
        }, 500);
      }, 600);
    });
  }
})();
