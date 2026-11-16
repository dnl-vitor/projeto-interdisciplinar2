# GIE_DATA v2 — Banco de dados do dashboard único

Banco MySQL 8.0+ do **Gestão Inteligente de Estufas**, reescrito a partir do
`Logico_gie.png`, do PDF do projeto e do `GIE.jar`. Sem cargos: um dashboard
único com abas, e **cada aba pode ser guardada como relatório, sempre com data e hora**.

Testado em MySQL 8.0.46 (a versão do dump da equipe): **45 testes automáticos, 45 aprovados**.

## 1. Instalação

```bash
mysql -u root -p < 01_schema.sql        # tabelas + triggers (NÃO apaga a tabela usuario)
mysql -u root -p < 02_views.sql         # views das abas do dashboard
mysql -u root -p < 03_procedures.sql    # irrigação, alertas, relatórios
mysql -u root -p < 04_seed_demo.sql     # (opcional) dados do DadosSistema.java + 24 h de leituras
mysql -u root -p < 05_events.sql        # (opcional) alertas a cada 5 min + relatório diário às 23:55
# edite a senha e rode user.sql           -> usuário 'gie_app' com privilégios mínimos
./rodar_testes.sh                         # cria GIE_TEST e roda 99_testes.sql (não toca no GIE_DATA)
```

Use o cliente `mysql` (os arquivos têm `DELIMITER`). No PHP, apenas **chame** as procedures.
Se `usuario` já existir na estrutura antiga, rode o bloco "MIGRAÇÃO" no fim do `01_schema.sql`.

## 2. A ideia central: aba = view = relatório

Cada aba lê **uma view** (estado ao vivo). Gerar o relatório é gravar essa mesma view
nas tabelas `rel_*`, então o que a aba mostra e o que o relatório guarda nunca divergem.

| Aba do dashboard    | View (ao vivo)                              | Relatório (histórico)                  |
|---------------------|---------------------------------------------|----------------------------------------|
| Visão geral (KPIs)  | `vw_dash_resumo`                            | cabeçalho `relatorio`                  |
| Áreas de cultivo    | `vw_dash_area`                              | `rel_area`                             |
| Plantas             | `vw_area_planta_detalhe`                    | `rel_area_planta`                      |
| Irrigação           | `vw_dash_reservatorio` + `hist_irrigacao`   | `rel_reservatorio` + `rel_irrigacao`   |
| Sensores / Ambiente | `vw_dash_sensor`                            | `rel_sensor`                           |
| Insumos / Estoque   | `vw_dash_insumo`                            | `rel_insumo`                           |
| Alertas             | `vw_dash_alerta`                            | `rel_alerta`                           |
| Relatórios (lista)  | `vw_relatorio_lista`                        | —                                      |

Os relatórios são **fotografias**: guardam também nomes e faixas ideais da época.
Renomear uma planta ou mudar um limite amanhã não altera o relatório de ontem (há teste para isso).

```sql
CALL sp_gerar_relatorio(1, 5, 'completo', NULL, NULL);          -- tudo, últimos 30 dias, usuário 5
CALL sp_gerar_relatorio(1, 5, 'insumos', '2026-11-01', NOW());  -- só a aba Insumos, período escolhido
CALL sp_gerar_relatorio(1, NULL, 'completo', NULL, NULL);       -- "Sistema (automático)"

SELECT * FROM vw_relatorio_lista ORDER BY gerado_em DESC;       -- aba Relatórios
SELECT * FROM rel_area WHERE fk_id_relatorio = 12;              -- abrir um relatório antigo

-- evolução entre relatórios (ex.: umidade do Canteiro A ao longo do tempo)
SELECT r.gerado_em, a.umidade, a.status_umidade
  FROM rel_area a JOIN relatorio r ON r.id_relatorio = a.fk_id_relatorio
 WHERE a.area_nome = 'Canteiro A' ORDER BY r.gerado_em;
```

Tipos de relatório: `completo`, `areas`, `plantas`, `irrigacao`, `sensores`, `insumos`, `alertas`.
O período (`p_inicio`/`p_fim`) vale para consumo de insumos, irrigações e perdas.
Tudo roda em uma transação: ou o relatório sai inteiro, ou não sai.

## 3. O que o banco garante sozinho (mesmo que o PHP erre)

| Regra (vinda do Java / PDF)                          | Onde está                                   |
|------------------------------------------------------|---------------------------------------------|
| Leitura impossível é recusada (umidade 150%, pH 15)  | `trg_leitura_bi`                            |
| Leitura de nível atualiza o volume da caixa          | `trg_leitura_ai`                            |
| Leitura atrasada não sobrescreve a mais nova         | `trg_leitura_ai`                            |
| "Estoque insuficiente de X" / abate estoque          | `trg_consumo_bi/ai` (basta `INSERT`)        |
| "Capacidade máxima atingida" (espécies por área)     | `trg_area_planta_bi`                        |
| Perda de planta abate do estágio                     | `trg_perda_bi/ai`                           |
| Sensor de umidade só liga a sensor do tipo umidade   | FK composta `(id, tipo)` com coluna gerada  |
| Um único alerta aberto por condição                  | índice único em `alerta.chave_aberta`       |
| App não altera relatório, consumo ou irrigação       | `user.sql` (SELECT/INSERT apenas)           |
| App não "forja" estoque, volume nem leitura em cache | `user.sql` (privilégio por coluna)          |

## 4. Integração com o PHP (PDO)

```php
$pdo = new PDO("mysql:host=$host;dbname=GIE_DATA;charset=utf8mb4", $user, $pass, [
  PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
  PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
  PDO::MYSQL_ATTR_INIT_COMMAND => "SET time_zone = '-03:00'",   // horário de Brasília
]);

// aba Áreas  ->  GET /api/areas
$areas = $pdo->query("SELECT * FROM vw_dash_area WHERE fk_id_garden = 1")->fetchAll();

// série para o gráfico (média por hora, 24 h)
$st = $pdo->prepare("SELECT DATE_FORMAT(data_hora,'%Y-%m-%d %H:00:00') AS t, ROUND(AVG(valor),2) AS v
                       FROM leitura_sensor
                      WHERE fk_id_sensor = ? AND data_hora >= NOW() - INTERVAL 24 HOUR
                      GROUP BY t ORDER BY t");

// telemetria / leitura manual -> um INSERT (os triggers fazem o resto)
$pdo->prepare("INSERT INTO leitura_sensor (fk_id_sensor, valor, origem, fk_id_usuario) VALUES (?,?,?,?)")
    ->execute([$sensor, $valor, 'manual', $_SESSION['id_usuario']]);

// irrigar  ->  as regras de negócio viram PDOException (SQLSTATE 45000), com mensagem pronta
try {
  $st = $pdo->prepare("CALL sp_irrigar_area(?,?,?,?,?)");
  $st->execute([$area, $caixa, $minutos, 'manual', $_SESSION['id_usuario']]);
  $resultado = $st->fetch();  $st->closeCursor();       // litros, minutos, volume_restante_l
} catch (PDOException $e) {
  http_response_code(422);
  echo json_encode(['erro' => $e->errorInfo[2]]);       // ex.: "Sistema de irrigacao desligado."
}
```

`/api/dashboard` e `/api/irrigacao/toggle` (que o `index_dashboard.js` já chama) passam a ser
só `SELECT` nas views e `UPDATE sistema_irrigacao SET lig_bol = ?`.

## 5. Mudanças em relação ao `Logico_gie.png`

| Item | Mudança | Por quê |
|---|---|---|
| `PERFIL_ACESSO`, `usuario.id_perfil` | **removidos** | sem cargos; o usuário só autentica e assina registros |
| `usuario` | `login` → `email` (já usado no PHP); + `status`, `criado_em`, `nome_comp` | UC01 "usuário inativo" |
| `AREA` | + `nome`, + `max_especies`; `area_m2` obrigatória | o dashboard precisa do nome ("Canteiro A") |
| `HIST_IRRIGACAO.id_area`, `REGISTRO_CONSUMO.id_area` | `VARCHAR(50)` → `INT` | era incompatível com `AREA.id_area INTEGER` |
| `HIST_IRRIGACAO` | tempo fracionário; `tipo_acionamento` ENUM; `fk_id_usuario` NULL = Sistema | UC03; o Java truncava p/ minuto inteiro |
| `REGISTRO_CONSUMO.motivo` | `VARCHAR(25)` → ENUM + `observacao` | evita texto livre |
| `AREA_PLANTA` | `quantidade_plantada` = quantidade **inicial**; + `area_planta_estagio` e `estagio_planta` | o Java guardava estágios (verdes, maduros…) |
| `INSUMO` | + `fk_id_garden`, `categoria`, `unidade` | no Java o estoque pertencia à estufa |
| `SENSOR_AMBIENTE.temp` | → `temp_min`/`temp_max` | `temp` duplicava `ult_leitura` |
| `SENSOR_CONTROLE` | `tipo` ENUM; + `ult_leitura_em` | detectar sensor offline |
| `GARDEN` | FK faltante p/ `sensor_ambiente` (existia no PNG, não no `schema.sql`); limiares configuráveis | integridade |
| `PLANTAS` | `necessidade_agua` → FK em `ref_necessidade_agua` | 3,0/2,0/0,5 L e faixas de umidade saem do código |
| **novas** | `leitura_sensor`, `alerta`, `entrada_insumo`, `registro_perda`, `relatorio` + 7 `rel_*` | histórico e relatórios |

O PDF promete "histórico confiável de leituras de temperatura, umidade e pH", mas o modelo
lógico só guardava a **última** leitura; `leitura_sensor` fecha essa lacuna.
Diagrama atualizado: `modelo_logico_v2.png` (gerado do próprio banco).

## 6. Bugs do GIE.jar corrigidos na versão web

Confirmados no código-fonte do PDF:

1. **pH do solo sempre "Fora da faixa"**: `Ph_eh_Adequado()` só tratava `tipo == "ph"`; o sensor `"ph_solo"` caía no `return false`.
2. **Umidade "Ideal: 70-30%"**: o construtor recebe `(umidMax, umidMin)` e o `DadosSistema` passa `(30, 70)`.
3. **Irrigação de 5 L com vazão de 8 L/min (0,63 min) irrigava 0 min**: `(int) Math.min(...)` truncava o tempo para minutos inteiros.
4. **Irrigação "forçada" não forçava nada**: os dois ramos do `if` chamavam o mesmo método.
5. **Nível da caixa**: `(vol/cap) * getNivelperc()` mistura fração com porcentagem e grava % onde a leitura é em metros.
6. **"Precisa irrigar" também disparava com solo encharcado** (`!Agua_eh_Adequada`); agora há `seco` e `encharcado` separados.
7. **Culturas incompatíveis na mesma área** (ex.: cacto + tomate + alface) geravam alertas eternos; agora viram o alerta `culturas_incompativeis`.

## 7. Decisões em aberto para a equipe

1. **Volume ideal de irrigação.** O Java soma 3,0/2,0/0,5 L **por espécie** na área; o UC03 diz "cada planta". As duas versões estão em `vw_area_parametros` (`volume_ideal_l` = Java; `volume_ideal_total_l` = litros × plantas). `sp_irrigar_area` usa a do Java; trocar é uma linha.
2. **Retenção de `leitura_sensor`.** 7 sensores a cada 30 s ≈ 20 mil linhas/dia. Sugestão: manter 90 dias e agregar por hora para o histórico longo.
3. **Irrigação automática** (`sp_irrigacao_automatica`) existe, mas **não está agendada** em `05_events.sql`: ela abre a água de verdade.
4. **Fuso horário.** Os `DATETIME` usam o fuso da sessão; configure `-03:00` no servidor ou na conexão (exemplo no item 4).
5. **E-mail com 50 caracteres** (limite herdado do `schema.sql` e do `cadastro.php`); aumente nos dois se necessário.
