repositório no github para o segundo semestre do projeto interdisciplinar.
professor: Flavio Massaro Rubens Junior
membros: Jão, Danilo, Gabriel, Guilherme e Victor

#  GIE — Gestão Inteligente de Estufas

Repositório do Projeto Interdisciplinar (2º Semestre).
* **Professor:** Flavio Massaro Rubens Junior
* **Integrantes:** Jão, Danilo, Gabriel, Guilherme e Victor

---

##  Como executar o projeto localmente (XAMPP / MySQL)

Siga os 4 passos abaixo para rodar o sistema completo com o banco de dados:

1. **Inicie o Servidor:**
   Coloque a pasta do projeto dentro de `C:\xampp\htdocs\` e inicie os módulos **Apache** e **MySQL** no painel do XAMPP.

2. **Configure a Conexão:**
   Na pasta `indexes/`, faça uma cópia do arquivo `conexao.example.php` e renomeie a cópia para **`conexao.php`**.
   *(Por padrão, ele já vem configurado para o XAMPP com usuário `root` e senha vazia).*

3. **Instale o Banco de Dados Automaticamente (1 clique):**
   Com o Apache e o MySQL ativos, acesse no navegador:http://localhost/dnl-vitor-projeto-interdisciplinar2/indexes/instalar_banco.php
    *(Ajuste o nome da pasta na URL caso tenha clonado com outro nome).*
Esse script criará automaticamente o banco `GIE_DATA`, todas as tabelas (`01_schema.sql`), views (`02_views.sql`), procedures (`03_procedures.sql`) e os dados iniciais de demonstração (`04_seed_demo.sql`).

4. **Acesse o Sistema:**
* **Página Inicial:** `indexes/index_home.html`
* **Cadastro / Login:** `indexes/index_cadastro.html` e `indexes/index_cardlogin.html`
* **Dashboard e Áreas:** `indexes/index_dashboard.php` e `indexes/index_areas.html`
