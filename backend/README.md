# Backend RotaSaúde (MVP – etapa 1)

API REST em Django + Django REST Framework + PostgreSQL, consumida pelo [app Flutter](../mobile/). A API pública é somente leitura; a escrita de leituras operacionais ocorre apenas pela [integração autenticada](#integração-de-estabelecimentos-etapa-2). Não há autenticação de usuários finais, Redis/Celery, WebSockets nem cálculo de indicadores.

> **Dados DEMONSTRATIVOS.** O seed cadastra quatro unidades fictícias de Goiânia para demonstração no app. Elas e suas leituras operacionais não são informações oficiais, atuais nem de estabelecimentos reais e vêm marcadas com `is_demo: true`.

## Stack

Python 3.12 (imagem Docker; validado também em 3.14), Django 5.2 LTS, DRF 3.16, django-cors-headers, psycopg 3, PostgreSQL 16. Versões fixadas em `requirements.txt`. Os filtros são simples e feitos na própria view, sem `django-filter`.

## Executar com Docker Compose

```bash
cd backend
cp .env.example .env            # ajuste os valores; nunca versione o .env
docker compose up --build       # sobe PostgreSQL e API (aplica migrações na partida)
docker compose exec api python manage.py seed_demo_units
curl http://127.0.0.1:8000/api/v1/units/
```

A configuração é de **desenvolvimento** (`runserver`); não há bind mount do código, então use `--build` após alterações. Para acessar de um aparelho físico na mesma rede, defina `API_BIND=0.0.0.0` no `.env`. Em emulador Android, o host é `10.0.2.2`.

Criar acesso ao Django Admin (`/admin/`):

```bash
docker compose exec api python manage.py createsuperuser
```

## Executar sem Docker

Requer um PostgreSQL acessível (veja `POSTGRES_*` no `.env`).

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env && set -a && source .env && set +a
python manage.py migrate
python manage.py seed_demo_units
python manage.py runserver
```

## Testes e verificações

O usuário do banco precisa poder criar o banco de testes (`test_<POSTGRES_DB>`).

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py test
# ou, com a stack do Compose no ar:
docker compose exec api python manage.py test
```

## Configuração (variáveis de ambiente)

Veja `.env.example`. Pontos importantes: `DJANGO_SECRET_KEY` é obrigatória quando `DJANGO_DEBUG=false`; `CORS_ALLOWED_ORIGINS` aceita somente origens explícitas (sem curinga) e só libera `GET`/`HEAD`/`OPTIONS`; o app Flutter nativo não depende de CORS.

## Endpoints (`/api/v1/`)

Os endpoints públicos (`health`, `units`, `services`) são somente leitura: `POST`, `PUT`, `PATCH` e `DELETE` retornam `405`, mesmo com uma chave de integração.

| Método | Rota | Descrição |
| --- | --- | --- |
| GET | `/api/v1/health/` | Health check (API + banco). `503` se o banco não responde. |
| GET | `/api/v1/units/` | Lista paginada de unidades ativas. Filtros: `?city=` (sem diferenciar maiúsculas) e `?service=` (nome do serviço). |
| GET | `/api/v1/units/{id}/` | Detalhe. `{id}` é o `external_id` público (ex.: `upa-centro`). |
| GET | `/api/v1/services/` | Lista paginada de serviços. |
| POST | `/api/v1/integrations/operational-status/` | Leitura operacional enviada por um estabelecimento (chave Bearer; veja abaixo). |
| GET | `/api/v1/routes/` | Rota de carro até uma unidade (`driving`; provedor configurável; veja [Rotas](#rotas-de-carro-osrm)). |

### Paginação

`?page=N&page_size=M` (padrão 20, máximo 100). Formato:

```json
{ "count": 4, "next": "http://…/units/?page=2", "previous": null, "results": [] }
```

### Exemplo: `GET /api/v1/units/upa-centro/`

```json
{
  "id": "upa-centro",
  "name": "UPA Exemplo Centro",
  "address": "Rua Exemplo, 120 · Setor Central, Goiânia",
  "city": "Goiânia",
  "state": "GO",
  "latitude": -16.6862,
  "longitude": -49.264,
  "phone": null,
  "opening_hours": "24 horas",
  "is_demo": true,
  "services": ["Clínica geral", "Ortopedia", "Pediatria"],
  "operational_status": {
    "people_waiting": 18,
    "estimated_wait_minutes": 20,
    "availability_level": "HIGH",
    "source_updated_at": "2026-11-11T00:15:49.618298-03:00",
    "received_at": "2026-11-11T00:15:49.618981-03:00",
    "is_demo": true
  },
  "last_operational_update_at": "2026-11-11T00:15:49.618298-03:00"
}
```

Unidade sem dados operacionais (ex.: `upa-oeste`): `"operational_status": null` e `"last_operational_update_at": null`. Nenhum valor é inventado; campos desconhecidos dentro de uma leitura também vêm `null`.

Notas de contrato para o Flutter:

- `id` é o `external_id`; o UUID interno não é exposto. Os campos usam `snake_case`.
- `availability_level`: `HIGH`, `MODERATE`, `LOW`, `CRITICAL` ou `null` (equivalentes ao `AvailabilityLevel` do app). Rótulos e cores ficam no app.
- `services` é uma lista de nomes em ordem alfabética.
- O app calcula a distância em linha reta no aparelho. O trajeto de carro vem de [`GET /api/v1/routes/`](#rotas-de-carro-osrm).
- O estado operacional mais recente é o de maior `source_updated_at`; todo o histórico fica no banco.

## Integração de estabelecimentos (etapa 2)

Sistemas de estabelecimentos enviam leituras operacionais por HTTP. Cada **chave de API** pertence a uma única unidade e só autoriza `POST /api/v1/integrations/operational-status/`. Não dá acesso ao Admin nem a qualquer outra rota, e a API pública continua somente leitura.

### Autenticação

- Header `Authorization: Bearer <chave>`. A chave (`rsi_` + 256 bits aleatórios de `secrets.token_urlsafe`) é exibida **uma única vez**, na emissão. O banco guarda só o SHA-256 e um prefixo de 12 caracteres (`key_prefix`) para identificação; logs mostram apenas o prefixo.
- Chave ausente, inválida, malformada ou revogada → `401` com a mesma mensagem genérica. Unidade diferente da credencial ou inexistente → `403` idêntico (não revela quais unidades existem).
- Revogação é imediata e definitiva (`revoked_at`). Não há exclusão de credenciais, para manter a trilha de auditoria. Para rotacionar, emita uma nova chave e revogue a antiga.
- Emitir, pelo Admin (`/admin/` → *Credenciais de integração* → adicionar; a chave aparece na mensagem de sucesso) ou pela linha de comando:

```bash
# imprime SOMENTE a chave no stdout; os metadados vão para o stderr
TOKEN=$(docker compose exec -T api python manage.py create_integration_credential upa-centro --name "Sistema X")
```

- Revogar: Admin → selecionar credenciais → ação **Revogar credenciais selecionadas**.
- Não guarde a chave em repositório, em histórico de shell compartilhado nem em tickets. Se for perdida, revogue e emita outra.

### Contrato do endpoint

`POST /api/v1/integrations/operational-status/` (`Content-Type: application/json`)

```json
{
  "unit_id": "upa-centro",
  "people_waiting": 18,
  "estimated_wait_minutes": 20,
  "availability_level": "HIGH",
  "source_updated_at": "2026-11-11T09:30:00-03:00"
}
```

| Campo | Regra |
| --- | --- |
| `unit_id` | Obrigatório; deve ser o `external_id` da unidade da credencial. |
| `people_waiting`, `estimated_wait_minutes`, `availability_level` | Obrigatórios, mas aceitam `null` (dado indisponível). Omitir o campo é erro `400`, para que um esquecimento não vire leitura vazia. Inteiros `0` a `100000` (pessoas) e `0` a `10080` (minutos), limites de sanidade de entrada; nível: `HIGH`, `MODERATE`, `LOW`, `CRITICAL`. A estimativa é a informada pela fonte; o backend não calcula nada. |
| `source_updated_at` | ISO 8601 **com fuso**. Sem fuso → `400`. Mais de 5 minutos no futuro → `400`. |
| Outros campos | Rejeitados (`400`), inclusive `received_at` e `is_demo`. O contrato não admite dados de pacientes. |

Respostas: `201` criada, `200` reenvio idêntico, `400` validação, `401`, `403`, `409` conflito, `415` não-JSON, `429` limite excedido.

### Regras de consistência

- **Histórico:** cada leitura é um registro. O banco impõe uma leitura por `(unidade, source_updated_at)` (`unique_unit_source_reading`), inclusive sob concorrência.
- **Reenvio idêntico** (mesmo instante e mesmos valores) é idempotente: `200`, nada novo é gravado.
- **Mesmo `source_updated_at` com valores diferentes** → `409 conflicting_reading`, devolvendo a leitura existente. Leituras são imutáveis; para corrigir, envie um novo `source_updated_at`. Nulo versus valor também é divergência.
- **Mais nova** que a atual → `201`, `is_latest: true`, e passa a ser o estado exposto na API pública.
- **Mais antiga** que a atual (entrega fora de ordem) → `201`, `is_latest: false`: fica no histórico, mas **nunca** vira o estado exibido. O "mais recente" é sempre o de maior `source_updated_at`.
- `received_at` é gerado pelo servidor.
- `is_demo` da leitura é herdado da unidade: leituras de unidades fictícias (as do seed) continuam marcadas como demonstrativas, e as de unidades reais não. Assim, uma credencial de teste nunca faz uma unidade fictícia parecer real. Para testar com dado "real", crie uma unidade com `is_demo=false`.
- O `seed_demo_units` só semeia unidades que ainda não têm leituras e nunca sobrepõe dados recebidos pela integração.

### Limite de requisições

`INTEGRATION_RATE_LIMIT` (padrão `60/min`), contado **por credencial**; excedido → `429` com `Retry-After`. Limitações: usa o cache padrão do Django (memória local), então o contador é por processo (com N workers o limite efetivo é até N vezes maior) e zera ao reiniciar; tentativas com chave inválida não são limitadas (a chave de 256 bits inviabiliza força bruta, mas convém limitar por IP no proxy reverso). Para produção, configure um cache compartilhado.

### Demonstração de ponta a ponta

Com a stack no ar e o seed aplicado (`upa-oeste` começa **sem** dados operacionais):

```bash
B=http://127.0.0.1:8000/api/v1

# 1) provisionar a chave de demonstração (não é impressa; fica só na variável)
TOKEN=$(docker compose exec -T api python manage.py create_integration_credential upa-oeste --name "Demo curl")

# 2) enviar uma leitura
curl -s -X POST $B/integrations/operational-status/ \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"unit_id\":\"upa-oeste\",\"people_waiting\":12,\"estimated_wait_minutes\":25,\"availability_level\":\"MODERATE\",\"source_updated_at\":\"$(date -Iseconds)\"}"

# 3) consultar a API pública
curl -s $B/units/upa-oeste/

# 4) confirmar: "operational_status" deixou de ser null e traz os valores enviados
# 5) revogar: Admin → Credenciais de integração → ação "Revogar"; o mesmo POST passa a responder 401
```

Exemplo de resposta do passo 2 (`201`):

```json
{
  "result": "created",
  "is_latest": true,
  "operational_status": {
    "people_waiting": 12,
    "estimated_wait_minutes": 25,
    "availability_level": "MODERATE",
    "source_updated_at": "2026-11-11T00:31:13-03:00",
    "received_at": "2026-11-11T00:31:13.113750-03:00",
    "is_demo": true
  }
}
```

## Rotas de carro (OSRM)

Roteamento real de **carro** via provedor configurável (`ROUTING_PROVIDER`, hoje `osrm`). A arquitetura usa `RoutingProvider` + `OSRMRoutingProvider`, preparada para um futuro `GoogleRoutesProvider` sem mudar o contrato HTTP.

### Configuração

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `ROUTING_PROVIDER` | `osrm` | Provedor ativo. |
| `OSRM_BASE_URL` | `https://router.project-osrm.org` | Base do serviço Route do OSRM. |
| `OSRM_TIMEOUT_SECONDS` | `10` | Timeout da chamada externa. |
| `ROUTING_CACHE_TTL` | `120` | Cache da resposta normalizada (segundos). Chave é hash; coordenadas não vão para log. |
| `ROUTING_RATE_LIMIT` | `30/min` | Limite por IP na API `/routes/`. |
| `OSRM_MIN_REQUEST_INTERVAL` | `1.0` | Intervalo mínimo entre **chamadas outbound** ao OSRM (cache compartilhado). |
| `OSRM_OUTBOUND_LOCK_TTL` | `30` | Trava para evitar consultas simultâneas ao servidor público. |

### Contrato HTTP

`GET /api/v1/routes/?origin_lat=&origin_lon=&unit_id=&mode=driving`

- Destino: coordenadas da unidade ativa no PostgreSQL (`external_id` = `unit_id`).
- `mode`: apenas `driving`. `bus`, `transit` e similares → `400` com mensagem explícita de transporte público indisponível.
- Erros: `400` validação, `404` unidade, `429` limite da API, `502` rota rejeitada pelo provedor, `503` provedor ocupado/indisponível/timeout. Detalhes internos não são expostos.
- Logs: apenas `unit_id` e `mode`; **não** registram coordenadas de origem.

Resposta (`200`):

```json
{
  "provider": "osrm",
  "mode": "driving",
  "unit_id": "upa-centro",
  "distance_meters": 582.4,
  "duration_seconds": 95.2,
  "geometry": {
    "type": "LineString",
    "coordinates": [[-49.2648, -16.6869], [-49.264, -16.6862]]
  }
}
```

`geometry.coordinates` segue GeoJSON: **`[longitude, latitude]`**.

### Limitações do OSRM público

O host `router.project-osrm.org` é **demonstração**: sem SLA, pode limitar taxa ou bloquear uso intensivo. Não use em produção. O backend mitiga com cache curto, throttle por IP, uma chamada outbound por vez e intervalo mínimo entre consultas ao OSRM — ainda assim convém instância OSRM própria ou Google Routes em produção.

Exemplo (Goiânia, após `seed_demo_units`):

```bash
curl -s "http://127.0.0.1:8000/api/v1/routes/?origin_lat=-16.6869&origin_lon=-49.2648&unit_id=upa-centro&mode=driving"
```

## Estrutura

```text
backend/
├── config/            settings, URLs versionadas, paginação e health check
├── apps/services/     Service
├── apps/units/        HealthUnit, HealthUnitService, UnitOperationalStatus,
│                      API de unidades e comando seed_demo_units
├── apps/integrations/ IntegrationCredential, autenticação por chave, throttle,
│                      endpoint de ingestão e comando create_integration_credential
├── apps/routing/      RoutingProvider, OSRM, GET /routes/
├── compose.yaml · Dockerfile · requirements.txt · .env.example
```

## Seed demonstrativo

`python manage.py seed_demo_units` é idempotente: atualiza as 4 unidades pelo `external_id`, garante serviços e vínculos sem duplicar e só grava uma nova leitura operacional quando os valores demonstrativos mudam. `upa-oeste` permanece sem dados operacionais. O `source_updated_at` das leituras demonstrativas é o momento da primeira execução do seed, e não uma medição real.

## Histórico operacional e Admin

Cada leitura é um registro novo em `UnitOperationalStatus`. No Admin, leituras podem ser criadas, mas não editadas nem apagadas, para preservar o histórico. Valores negativos são rejeitados na validação e por `CHECK` no banco.

## Limitações conhecidas

- Imagem e Compose são de desenvolvimento: falta servidor WSGI/ASGI, arquivos estáticos do Admin e endurecimento de produção (`check --deploy`).
- Endpoints públicos de unidades/serviços sem autenticação; `/routes/` tem throttle por IP e depende de provedor externo (veja [Rotas](#rotas-de-carro-osrm)).
- A migração `units.0002` (unicidade da leitura) falha se já existirem duas leituras da mesma unidade no mesmo `source_updated_at`; não há tal caso nos dados do seed.
- Coordenadas em `FloatField`; PostGIS (busca por proximidade) fica para quando for necessário.
