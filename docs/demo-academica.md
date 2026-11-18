# Demonstração acadêmica do RotaSaúde

> **Dados simulados — demonstração acadêmica.** Tudo que este modo gera (UPAs extras, filas, esperas, linhas de ônibus, pontos e horários) é fictício. Não representa estabelecimentos, métricas clínicas, tempos de atendimento nem transporte público reais, e não serve para tomar decisões de saúde ou de deslocamento.

## 1. Objetivo

Permitir apresentar o RotaSaúde de ponta a ponta (Django + PostgreSQL + Flutter) com dados controlados e repetíveis: filas baixas e críticas, informação desatualizada, ausência de dados, falha de atualização, atualização periódica, comparação entre unidades e rota de **ônibus simulada**, ao lado da rota de carro real (OSRM), que não muda.

Os mocks **complementam** a aplicação. As telas continuam lendo a API real (`/api/v1/units/`, `/api/v1/routes/`); o simulador só grava leituras pelo mesmo modelo (`UnitOperationalStatus`) que a integração usa, sempre marcadas com `is_demo: true`.

## 2. Como ativar

O modo é opt-in, **desligado por padrão** e só vale com `DJANGO_DEBUG=true`.

```env
# backend/.env
DJANGO_DEBUG=true
DEMO_MODE=true
```

| Situação | Efeito |
| --- | --- |
| `DEMO_MODE` ausente ou `false` | Nada muda: os comandos de simulação recusam gravar e `mode=bus` continua respondendo `400`. |
| `DEMO_MODE=true` com `DJANGO_DEBUG=true` | Comandos liberados e `mode=bus` devolve a rota simulada. |
| `DEMO_MODE=true` com `DJANGO_DEBUG=false` | A aplicação **não inicia** (`ImproperlyConfigured`): dados simulados nunca chegam a um ambiente sem debug. |

Subir o Django não cria dados nem inicia simulação. Nenhum endpoint administrativo é exposto.

## 3. Iniciar, usar e encerrar o ambiente (Podman)

### 3.1 Padrão deste ambiente

Tudo roda no projeto Compose **`rotasaude_demo`** (sempre com `-p rotasaude_demo`; sem isso o diretório `backend` viraria o nome do projeto e colidiria com contêineres de outros worktrees).

| Item | Valor |
| --- | --- |
| Projeto Compose | `rotasaude_demo` (contêineres `rotasaude_demo_db_1` e `rotasaude_demo_api_1`) |
| Volume do banco | `rotasaude_demo_pgdata` (nunca é removido pelos scripts) |
| Banco / usuário | `rotasaude` / `rotasaude` |
| Postgres (contêiner → host) | `5432` → `127.0.0.1:55434` |
| API Django (contêiner → host) | `8000` → `127.0.0.1:8001` |
| Modo | `DJANGO_DEBUG=true`, `DEMO_MODE=true` |

### 3.2 Primeira vez: configurar o `.env`

```bash
cd backend
cp .env.example .env            # só se ainda não existir; o .env nunca vai para o Git
```

Edite `backend/.env` (valores de desenvolvimento, nunca credenciais reais):

```env
DJANGO_DEBUG=true
DEMO_MODE=true
DJANGO_SECRET_KEY=<uma chave sua, diferente da senha do banco>
POSTGRES_DB=rotasaude
POSTGRES_USER=rotasaude
POSTGRES_PASSWORD=<senha do banco>
POSTGRES_HOST_PORT=55434
API_PORT=8001
COMPOSE_PROJECT_NAME=rotasaude_demo
```

> **A senha é gravada no volume na primeira inicialização do Postgres.** Depois disso, alterar `POSTGRES_PASSWORD` no `.env` **não** altera o banco: a API passa a falhar com `password authentication failed`. Se for preciso trocar, altere dentro do banco (`ALTER USER`) e no `.env` ao mesmo tempo; não apague o volume.

### 3.3 Iniciar (um comando)

```bash
./scripts/start-demo.sh          # --no-build reaproveita a imagem atual
```

O script é **idempotente** (pode ser repetido) e nunca remove volumes, bancos ou tabelas. Em ordem, ele: valida o `.env` (sem exibir segredos) e exige `DJANGO_DEBUG=true` e `DEMO_MODE=true`; confere se as portas do host estão livres; sobe o projeto `rotasaude_demo` (`up -d --build`); espera o Postgres ficar saudável; confirma a autenticação API → banco pelo `/api/v1/health/`; roda `migrate` e `check`; confirma `DEBUG` e `DEMO_MODE` dentro do contêiner; roda `seed_demo_scenarios`; aplica `simulate_operational_status --all --scenario baseline`; mostra `show_demo_status`; e imprime a URL da API e os passos do Flutter.

O `baseline` respeita os papéis reservados: `upa-oeste` (sem dados), `upa-leste` (desatualizada) e `upa-sudoeste` (falha de atualização) não são alteradas por `--all`.

> Variáveis exportadas no shell (`POSTGRES_*`, `DJANGO_*`, `DEMO_*`, `API_*`, `COMPOSE_*`) **sobrepõem** o `.env` na interpolação do `podman-compose`, mas só afetam o serviço `db`. Foi assim que o banco e a API podem acabar com senhas diferentes. Os scripts removem essas variáveis do próprio processo; em comandos manuais, use sempre `podman compose -p rotasaude_demo --env-file .env ...` a partir de `backend/`.

### 3.4 Conferir o banco

```bash
podman ps --filter name=rotasaude_demo_                       # db "healthy", api "Up"
podman exec rotasaude_demo_db_1 pg_isready -U rotasaude -d rotasaude
podman exec rotasaude_demo_db_1 psql -U rotasaude -d rotasaude -c '\dt'
podman exec rotasaude_demo_api_1 python manage.py showmigrations | grep -c '\[ \]'   # 0 = nada pendente
podman exec rotasaude_demo_api_1 python manage.py show_demo_status
```

O `psql` dentro do contêiner usa o socket local (autenticação `trust`), então **não prova** que a senha do `.env` está certa. A prova é a API responder `{"status":"ok","database":"ok"}` em `/api/v1/health/`, porque ela conecta pela rede com a senha do `.env`.

### 3.5 Consultar a API

```bash
curl -s http://127.0.0.1:8001/api/v1/health/
curl -s http://127.0.0.1:8001/api/v1/units/
curl -s "http://127.0.0.1:8001/api/v1/routes/?origin_lat=-16.6869&origin_lon=-49.2648&unit_id=upa-centro&mode=driving"
curl -s "http://127.0.0.1:8001/api/v1/routes/?origin_lat=-16.6869&origin_lon=-49.2648&unit_id=upa-centro&mode=bus"   # simulada: exige DEMO_MODE=true
```

`mode=driving` usa o OSRM público (precisa de internet). `mode=bus` não usa serviço externo.

### 3.6 Conectar um Android físico

```bash
adb devices                                   # o aparelho deve aparecer como "device"
adb reverse tcp:8001 tcp:8001                 # repita se reconectar o cabo ou a depuração sem fio
cd mobile
flutter run -d <ID_DO_APARELHO> --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

Com `adb reverse`, `127.0.0.1:8001` no celular chega à API deste computador sem alterar `API_BIND` nem `DJANGO_ALLOWED_HOSTS`. O app não tem a porta fixa no código: ela vem de `API_BASE_URL`. Outras formas de conexão estão no `README.md` (troque 8000 por 8001).

### 3.7 Simular atualizações durante a apresentação

```bash
podman exec rotasaude_demo_api_1 python manage.py simulate_operational_status --unit upa-centro --scenario critical
podman exec rotasaude_demo_api_1 python manage.py simulate_operational_status --all --scenario baseline
```

Detalhes e todos os cenários estão na seção 5. Nos exemplos das seções 4 a 6, `python manage.py …` equivale ao prefixo `podman exec rotasaude_demo_api_1` acima.

### 3.8 Encerrar e retomar

```bash
./scripts/stop-demo.sh           # para API e Postgres do rotasaude_demo; mantém contêineres, banco e volume
./scripts/start-demo.sh          # retoma depois; os dados continuam lá
```

`stop-demo.sh` só para contêineres cujo nome começa com `rotasaude_demo_`. Ele nunca usa `down -v`, `volume rm`, `volume prune` ou `system prune`, e não toca em outros projetos. Dados antigos ficam no volume: ao retomar, as leituras de ontem aparecem como desatualizadas até o `baseline` (o `start-demo.sh` já o aplica).

### 3.9 Problemas comuns

| Sintoma | Causa provável | O que fazer (sem apagar dados) |
| --- | --- | --- |
| `password authentication failed for user "rotasaude"` na API | A senha do `.env` difere da gravada no volume na primeira inicialização | Restaure no `.env` a senha original (ela também está no ambiente do contêiner `db`: `podman inspect rotasaude_demo_db_1`). Não recrie o volume. Depois, `./scripts/start-demo.sh` |
| `database "..." does not exist` | `POSTGRES_DB` do `.env` não é o banco existente | Use `POSTGRES_DB=rotasaude`. Não crie bancos extras |
| API em `Exited (1)` | Falha no `migrate` inicial (quase sempre a senha acima) | `podman logs rotasaude_demo_api_1` e corrija a causa; `start-demo.sh` recria a API |
| `bind: address already in use` / script recusa a porta | Outro contêiner/processo usa 55434 ou 8001 | `podman ps -a` e `ss -ltn`; encerre o que não for da demonstração ou mude as portas no `.env` |
| `.env` alterado mas nada mudou | Variáveis e portas são fixadas na criação do contêiner | Rode `./scripts/start-demo.sh`: o `podman-compose` recria só os serviços cuja configuração mudou, preservando o volume |
| App sem conexão no celular | Falta o `adb reverse` ou a porta do `--dart-define` está errada | Refaça os comandos da seção 3.6 |
| `mode=bus` responde `400` | `DEMO_MODE` falso na API | Ajuste o `.env` e rode `start-demo.sh` |
| `mode=bus` responde `404` | Origem fora de Goiânia (raio de 35 km) ou unidade não demonstrativa | Use uma origem em Goiânia |

**Sem contêiner** (PostgreSQL acessível; veja `backend/README.md`):

```bash
cd backend
source .venv/bin/activate
set -a && source .env && set +a
export POSTGRES_PORT=55434         # porta publicada no host (a API em contêiner usa 5432 internamente)
python manage.py migrate
python manage.py runserver
```

## 4. Preparar as UPAs

```bash
python manage.py seed_demo_scenarios
```

É idempotente e não destrutivo: garante as 4 UPAs de `seed_demo_units` e 3 UPAs fictícias extras e dá a cada uma seu papel. Só acrescenta leituras a unidades ainda não preparadas; nunca altera nem apaga leituras existentes, e recusa o comando se um `external_id` da demonstração já pertencer a uma unidade **não** demonstrativa.

| UPA | Papel | O que a leitura inicial mostra |
| --- | --- | --- |
| `upa-centro` | Cenário A · movimento baixo | 8 pessoas · 15 min · `HIGH` |
| `upa-sul` | Cenário B · movimento moderado | 27 pessoas · 45 min · `MODERATE` |
| `upa-norte` | Cenário C · movimento elevado | 48 pessoas · 80 min · `LOW` |
| `upa-nordeste` | Cenário D · situação crítica | 64 pessoas · 110 min · `CRITICAL` |
| `upa-oeste` | **Sem dados** operacionais | `operational_status: null` |
| `upa-leste` | **Informação desatualizada** | última leitura há ~3 h (o app a trata como antiga) |
| `upa-sudoeste` | **Falha de atualização** | leitura boa seguida de uma leitura sem valores (todos `null`) |

As leituras iniciais envelhecem: passados 30 minutos o app as chama de desatualizadas. Para renová-las antes de apresentar, use `--scenario baseline` (seção 5).

`upa-oeste`, `upa-leste` e `upa-sudoeste` são **reservadas** para demonstrar ausência de dados: `--all` não as altera.

## 5. Cenários e simulação de atualizações

Os números são fixos por cenário e **não há fórmula** ligando pessoas à espera: cada cenário define os três valores (o simulador não "calcula" tempo de espera).

| Chave | Cenário | Pessoas | Espera (min) | Disponibilidade |
| --- | --- | --- | --- | --- |
| `low` | A · movimento baixo | 8 | 15 | `HIGH` |
| `moderate` | B · movimento moderado | 27 | 45 | `MODERATE` |
| `high` | C · movimento elevado | 48 | 80 | `LOW` |
| `critical` | D · situação crítica | 64 | 110 | `CRITICAL` |
| `unavailable` | Falha de atualização | — | — | — (todos `null`) |
| `random` | Sorteia entre A–D, nunca repetindo o anterior da unidade | | | |
| `baseline` | Volta cada UPA ao seu cenário de partida (tabela da seção 4) | | | |

```bash
# uma UPA, uma vez
python manage.py simulate_operational_status --unit upa-centro --scenario critical --once

# todas as UPAs de cenário, uma vez
python manage.py simulate_operational_status --all --scenario moderate --once

# renovar a demonstração (cada UPA no cenário de partida)
python manage.py simulate_operational_status --all --scenario baseline

# atualização periódica a cada 60 s, com cenários aleatórios
python manage.py simulate_operational_status --all --scenario random --interval 60

# falha temporária e recuperação
python manage.py simulate_operational_status --unit upa-sul --scenario unavailable
python manage.py simulate_operational_status --unit upa-sul --scenario low
```

Opções: `--unit ID` (repetível) ou `--all`; `--once` (padrão) ou `--interval SEGUNDOS` (mínimo 5); `--iterations N` (com `--interval`, para após N ciclos); `--seed N` (sorteio reprodutível).

Garantias: só atua em unidades `is_demo` ativas (`--unit` de uma unidade real é recusado e nada é gravado); cada execução **acrescenta** leituras ao histórico; o `source_updated_at` é sempre posterior à leitura mais recente e não passa da tolerância de 5 min no futuro da integração; cada leitura e sua marca de cenário são gravadas na mesma transação; duas simulações simultâneas não geram leituras conflitantes (a linha da unidade é travada).

### Interromper

O modo periódico só começa quando você o executa. Encerre com **Ctrl+C** (ou `SIGTERM`): o ciclo em andamento termina, os manipuladores de sinal são restaurados e o comando imprime `Simulação encerrada após N ciclo(s).` Nada fica rodando em segundo plano.

### Conferir o estado

```bash
python manage.py show_demo_status                              # todas as UPAs demonstrativas
python manage.py show_demo_status --unit upa-centro --history 10   # últimas 10 leituras
```

Mostra, por UPA: papel, cenário aplicado, pessoas, espera, disponibilidade, hora e idade da última leitura e a situação da atualização (**atual**, **desatualizada** ou **sem dados**, pela mesma regra do app: janela de 30 min, configurável em `DEMO_STALE_AFTER_MINUTES`). É somente leitura e funciona mesmo com o modo desligado.

Não há endpoint HTTP de histórico: o MVP não precisa dele, e `show_demo_status --history` cobre a consulta sem ampliar a superfície pública.

## 6. Rotas de ônibus simuladas

`GET /api/v1/routes/?origin_lat=&origin_lon=&unit_id=&mode=bus` (também aceita `transit` e `public_transport`). Só funciona com o modo de demonstração ativo e para unidades `is_demo`. Não chama OSRM, Google ou qualquer API externa. `mode=driving` não foi alterado.

```bash
curl -s "http://127.0.0.1:8001/api/v1/routes/?origin_lat=-16.6869&origin_lon=-49.2648&unit_id=upa-sul&mode=bus"
```

A resposta mantém os campos da rota de carro (`provider`, `mode`, `unit_id`, `distance_meters`, `duration_seconds`, `geometry`) e acrescenta:

| Campo | Significado |
| --- | --- |
| `is_simulated` | Sempre `true`; `simulation_notice` traz o aviso por extenso (o app não o exibe). |
| `route_id`, `line` | Identificador e linha (`DEMO-A1`, `DEMO-B2`, `DEMO-C3`, exibidas no app como “Linha A1”, “B2” e “C3”; não existem). |
| `boarding_stop`, `alighting_stop` | Pontos simulados (nome, latitude, longitude). |
| `walk_to_stop_*`, `wait_seconds`, `in_vehicle_seconds`, `walk_from_stop_*` | Caminhada inicial, espera, tempo no ônibus e caminhada final. |
| `departure_at`, `bus_departure_at`, `bus_arrival_at`, `arrival_at` | Saída da origem, saída/chegada do ônibus e chegada à unidade (ISO 8601). Horários **fictícios**, não oficiais. |
| `geometry`, `geometry_kind` | GeoJSON `[lon, lat]`; `schematic` = linhas retas entre origem, pontos e unidade, sem malha viária. |

Modelo (fixo e determinístico): caminhada a 4,5 km/h com trajeto 30% maior que a linha reta; ônibus a 18 km/h com trajeto 35% maior; pontos a 12% da distância de cada ponta (entre 150 m e 400 m); cada linha sai a cada 15, 20 ou 30 min em um minuto fixo da hora; a linha é escolhida pelo `unit_id`.

Respostas: `200` rota; `400` modo de demonstração desligado (mensagem original de transporte público indisponível) ou modo não suportado; `404` unidade inexistente, unidade **não** demonstrativa, origem fora da região de Goiânia (raio de 35 km) ou unidade a menos de 1 km em linha reta.

No app, a tela **Rota até a unidade** ganhou o seletor **Carro | Ônibus**. A aba **Comparar** calcula o tempo de ônibus sob demanda. O app **não exibe aviso** de dados simulados; a marcação existe só na API (`is_demo`, `is_simulated`) e nos comandos de terminal.

## 7. Executar o Flutter

```bash
cd mobile
flutter pub get
adb -s <ID_DO_DISPOSITIVO> reverse tcp:8001 tcp:8001
flutter run -d <ID_DO_DISPOSITIVO> --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

Outras formas de conectar (emulador, rede local, sem cabo) estão no `README.md`. O app **reconsulta as unidades a cada 30 s** enquanto a Lista/Mapa/Comparar estão abertos, sem reabrir a tela; a rotina é silenciosa e, se a rede falhar, mantém o que já está na tela. Detalhes e Rota abertos não se atualizam sozinhos: volte e abra de novo.

## 8. Limitações dos dados fictícios

- Nada é medição: pessoas, esperas, níveis, linhas, pontos e horários são inventados e voltam a ser inventados a cada execução.
- O ônibus simulado não conhece ruas, sentidos, trânsito, feriados nem lotação, e o traçado é esquemático. Os horários seguem uma grade fictícia. **Não é navegação.**
- Há rota de ônibus apenas para as UPAs demonstrativas e para a região de Goiânia.
- Leituras são imutáveis: não há "desfazer". Se a demonstração ficar confusa, rode `--scenario baseline`; o histórico antigo permanece (use `show_demo_status --history`). A demonstração não oferece limpeza destrutiva por decisão de projeto.
- Os papéis "sem dados", "desatualizada" e "falha" só são montados em UPAs sem leituras. Uma vez enviada uma leitura nova a `upa-leste` ou `upa-oeste` (por `--unit` ou pela integração), ela deixa de representar o papel; para repeti-lo, use um banco de demonstração novo.
- O tempo de atualização do app (30 s) e a janela de dado antigo (30 min) são do cliente; `DEMO_STALE_AFTER_MINUTES` só afeta o relatório do terminal.
- A verificação visual em aparelho Android físico não faz parte dos testes automatizados.

## 9. Roteiro curto de apresentação (≈6 min)

1. **Preparo (antes):** `./scripts/start-demo.sh` (faz `migrate`, `seed_demo_scenarios`, `baseline` e `show_demo_status`). Abra o app e escolha **Goiânia**.
2. **Mapa e Lista:** 7 UPAs fictícias, sem aviso na tela. Mostre `upa-nordeste` (crítica, 110 min), `upa-centro` (baixa, 15 min), `upa-leste` (*Espera sem atualização*) e `upa-oeste` (*sem estimativa*).
3. **Atualização ao vivo:** em um terminal, `simulate_operational_status --unit upa-centro --scenario critical`. Em até 30 s a Lista passa de 15 para 110 min. Depois `--scenario unavailable` (dado indisponível) e `--scenario low` (recuperação).
4. **Periódico:** `simulate_operational_status --all --scenario random --interval 20`; mostre as mudanças e interrompa com Ctrl+C.
5. **Comparar:** selecione duas UPAs; alterne **Carro | Ônibus** e use *Calcular tempos*.
6. **Rota:** em **Ver rota**, mostre o carro (OSRM real) e depois **Ônibus**: linha, caminhada, espera e horários.
7. **Histórico e integridade:** `show_demo_status --unit upa-centro --history 10` mostra que nada foi sobrescrito.
8. **Fechamento (opcional):** com `DEMO_MODE=false` na API, `mode=bus` volta a responder `400` e os comandos de simulação recusam gravar; com `DJANGO_DEBUG=false` o modo nem inicia. O `start-demo.sh` exige o modo ligado, então, para mostrar isso ao vivo, edite o `.env` e recrie só a API: `cd backend && podman compose -p rotasaude_demo --env-file .env up -d --force-recreate api` (o banco e o volume não são tocados). Volte `DEMO_MODE=true` e rode o `start-demo.sh` depois.

## 10. Testes

```bash
# backend (banco de testes isolado test_<POSTGRES_DB>; exige PostgreSQL acessível)
cd backend && python manage.py test apps.demo   # ou: python manage.py test

# mobile
cd mobile && flutter analyze && flutter test
```

Cobertura relevante: `apps/demo/tests/` (guarda do modo, cenários, simulador, histórico e timestamps, execução repetida, unidades reais intactas, seed idempotente, `show_demo_status`, rota de ônibus e compatibilidade de `driving`) e, no Flutter, `transit_demo_test.dart`, `operational_refresh_test.dart`, `route_parser_test.dart`, `route_repository_test.dart` e `api_contract_test.dart` (com a fixture `route_bus_simulated.json` gerada pelo backend).
