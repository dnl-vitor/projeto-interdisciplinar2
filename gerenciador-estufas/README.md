# GIE — Gestão Inteligente de Estufas

Front-end da landing page e da tela de login do sistema de gestão de estufas.
Etapa atual: **Landing Page + Login**. O Dashboard e suas rotas por perfil
entram na próxima etapa.

## Como visualizar

Não há build nem dependências. Basta abrir `index.html` no navegador, ou
servir a pasta com um servidor estático simples:

```bash
npx serve .
# ou
python3 -m http.server 8080
```

## Estrutura de pastas

```
gerenciador-estufas/
├── index.html              # Landing page (Home, Funcionalidades, Cadastro,
│                            #   Contato, Equipe, Suporte)
├── login.html               # Tela de login (com simulação de perfil para
│                            #   testar o Dashboard mais adiante)
├── dashboard.html           # Placeholder — confirma o login e a sessão local;
│                            #   será substituído pelo Dashboard real
│
├── src/
│   ├── styles/
│   │   ├── variables.css    # Tokens: cores, tipografia, espaçamento
│   │   ├── base.css         # Reset e estilos globais
│   │   ├── components.css   # Botões, formulários, tabelas, cards, nav, FAQ
│   │   ├── landing.css      # Layout específico da landing page
│   │   └── login.css        # Layout específico do login
│   │
│   ├── scripts/
│   │   ├── landing.js       # Menu mobile, FAQ, formulários (simulados)
│   │   └── login.js         # Validação, sessão local, redirecionamento
│   │
│   └── assets/
│       └── icons/           # Reservado para ícones/imagens adicionais
│
└── README.md
```

## Sistema de design

- **Cores**: verdes de copa e folha como base, um dourado-terra (`--soil-gold`)
  como acento, e três tons de status (`ok`, `amber`, `red`) usados nos badges
  de alerta — a mesma lógica de alertas do back-end (`InsumoController`,
  `Garden.verificarAlertas`).
- **Tipografia**: `Fraunces` para títulos, `Work Sans` para o corpo,
  `IBM Plex Mono` para leituras de sensores e rótulos técnicos — reforça a
  ideia de dados de telemetria sem recorrer a decoração genérica.
- Tokens completos em `src/styles/variables.css`.

## Perfis de acesso (para a próxima etapa)

O login já grava uma sessão local (`localStorage`, chave `gie_sessao`) com
`email` e `perfil`. O Dashboard deve ler essa sessão e exibir:

| Perfil          | Funcionalidades                                                        |
|------------------|-------------------------------------------------------------------------|
| Administrador    | Relatório completo, alertas globais, cadastro de plantas/insumos/áreas |
| Vendedor         | Balanço de insumos, mapa de culturas, registro de saída de insumos     |
| Produtor         | Alertas, correção de pH, irrigação manual, telemetria, perdas, manejo  |

Essa divisão segue a mesma organização do back-end em Java já existente
(`GerenciadorMenus`, `AreaEstufa`, `Sensor`, `SistemaIrrigacao`,
`InsumoController`), o que deve facilitar o encaixe das rotas do Dashboard
com os dados reais quando a integração acontecer.

## Observações

- Os formulários de Cadastro e Contato, e o botão de download, estão
  **simulados em JavaScript** — não há backend conectado nesta etapa.
- Os cards da seção "Equipe do Projeto" usam nomes fictícios como modelo;
  substitua pelos nomes reais da equipe.
