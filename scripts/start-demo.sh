#!/usr/bin/env bash
# Sobe a demonstração acadêmica do RotaSaúde (Postgres + API Django) no projeto Podman
# `rotasaude_demo`, prepara os dados fictícios e imprime os próximos passos do Flutter.
#
# Idempotente: pode ser executado quantas vezes for preciso. Nunca remove volumes,
# bancos ou tabelas e só mexe em contêineres do projeto `rotasaude_demo`.
#
# Uso: ./scripts/start-demo.sh [--no-build]
set -euo pipefail

# shellcheck source=scripts/_demo_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_demo_common.sh"

BUILD_FLAG="--build"
case "${1:-}" in
  "") ;;
  --no-build) BUILD_FLAG="" ;;
  -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "Argumento desconhecido: $1 (use --no-build ou --help)." ;;
esac

manage() { compose exec -T api python manage.py "$@"; }

info "1/10 Validando configuração (backend/.env)"
require_tools
neutralize_shell_overrides
validate_config
ok "projeto=$PROJECT  banco=$POSTGRES_DB_NAME  usuário=$POSTGRES_USER_NAME  Postgres=:$DB_HOST_PORT  API=:$API_PORT"
ok "DJANGO_DEBUG=true e DEMO_MODE=true (segredos não são exibidos)"

info "2/10 Verificando portas do host"
for pair in "$DB_HOST_PORT:db" "$API_PORT:api"; do
  port="${pair%%:*}"; service="${pair##*:}"
  if port_busy "$port" && ! podman ps --filter "name=^${PROJECT}_${service}_" --format '{{.Ports}}' | grep -q ":${port}->"; then
    die "A porta $port do host está em uso por outro processo/contêiner (não é deste projeto). Libere-a ou altere o .env."
  fi
done
ok "portas $DB_HOST_PORT e $API_PORT livres ou já usadas por este projeto"

info "3/10 Subindo banco e API (podman compose -p $PROJECT up -d $BUILD_FLAG db api)"
if podman volume exists "$VOLUME" 2>/dev/null; then
  ok "volume $VOLUME existente será reutilizado"
else
  warn "volume $VOLUME ainda não existe: será criado agora (primeira execução)"
fi
# O simulador só sobe no passo 9, depois do baseline, para não ter seus sorteios sobrescritos.
compose up -d $BUILD_FLAG db api 2>&1 | mask | tail -n 5

# O podman-compose não recria um contêiner cuja configuração não mudou, mesmo com imagem nova.
# Se o código do backend mudou, recria só a API (banco e volume não são tocados).
built_image="$(podman image inspect -f '{{.Id}}' "localhost/${PROJECT}_api:latest" 2>/dev/null || true)"
running_image="$(podman inspect -f '{{.Image}}' "${PROJECT}_api_1" 2>/dev/null || true)"
if [ -n "$built_image" ] && [ "$built_image" != "$running_image" ]; then
  ok "imagem da API atualizada: recriando só a API"
  compose up -d --no-deps --force-recreate api 2>&1 | mask | tail -n 3
fi

info "4/10 Aguardando o Postgres ficar saudável"
db_container="${PROJECT}_db_1"
for _ in $(seq 1 60); do
  [ "$(podman inspect -f '{{.State.Health.Status}}' "$db_container" 2>/dev/null || true)" = "healthy" ] && break
  sleep 1
done
[ "$(podman inspect -f '{{.State.Health.Status}}' "$db_container" 2>/dev/null || true)" = "healthy" ] \
  || die "Postgres não ficou saudável em 60 s. Veja: podman logs $db_container"
ok "Postgres saudável"

info "5/10 Verificando a conexão API → banco (autenticação por rede)"
health_url="http://127.0.0.1:${API_PORT}/api/v1/health/"
api_ready=0
for _ in $(seq 1 60); do
  if curl -fsS --max-time 3 "$health_url" 2>/dev/null | grep -q '"database":"ok"'; then api_ready=1; break; fi
  podman inspect -f '{{.State.Running}}' "${PROJECT}_api_1" 2>/dev/null | grep -q true || break
  sleep 1
done
if [ "$api_ready" -ne 1 ]; then
  warn "A API não respondeu com banco OK. Últimas linhas do log (sem segredos):"
  podman logs --tail 15 "${PROJECT}_api_1" 2>&1 | mask >&2 || true
  if podman logs "${PROJECT}_api_1" 2>&1 | grep -q 'password authentication failed'; then
    warn "Autenticação recusada: a senha do .env difere da gravada no volume $VOLUME."
    warn "Não recrie o volume. Veja 'Problemas comuns' em docs/demo-academica.md."
  fi
  die "API → banco indisponível."
fi
ok "GET /api/v1/health/ → status ok, database ok"

info "6/10 Migrações e verificação do Django"
manage migrate --noinput 2>&1 | tail -n 3
manage check 2>&1 | tail -n 1
manage shell -c "
import sys
from django.conf import settings
sys.exit(0 if (settings.DEBUG and settings.DEMO_MODE) else 1)" >/dev/null 2>&1 \
  || die "O contêiner da API está com DEBUG/DEMO_MODE falsos. Recrie-o: ./scripts/start-demo.sh (após ajustar o .env)."
ok "DEBUG=True e DEMO_MODE=True dentro da API"

info "7/10 Cadastrando as UPAs fictícias"
manage seed_demo_scenarios 2>&1 | tail -n 12

info "8/10 Aplicando o cenário baseline (UPAs sem dados e desatualizada preservadas)"
manage simulate_operational_status --all --scenario baseline 2>&1 | tail -n 8
manage show_demo_status 2>&1 | tail -n 40

info "9/10 Atualização automática (serviço simulator)"
simulator="${PROJECT}_simulator_1"
if is_true "$(env_get DEMO_AUTO_UPDATE)"; then
  # Recriado sempre: aplica o .env e a imagem atuais. Histórico e volume não são tocados.
  compose up -d $BUILD_FLAG --no-deps --force-recreate simulator 2>&1 | mask | tail -n 3
  sleep 3
  podman inspect -f '{{.State.Running}}' "$simulator" 2>/dev/null | grep -q true \
    || { podman logs --tail 15 "$simulator" 2>&1 | mask >&2 || true; die "O simulador não ficou em execução."; }
  podman logs --tail 4 "$simulator" 2>&1 | mask
  interval="$(env_get DEMO_UPDATE_INTERVAL)"
  ok "simulador ativo a cada ${interval:-60}s (logs: podman logs -f $simulator)"
else
  if podman inspect -f '{{.State.Running}}' "$simulator" 2>/dev/null | grep -q true; then
    podman stop -t 15 "$simulator" >/dev/null && ok "simulador parado (DEMO_AUTO_UPDATE desligado)"
  fi
  ok "atualização automática desligada (DEMO_AUTO_UPDATE=false); use o simulador manual abaixo"
fi

info "10/10 Verificação final"
units_json="$(curl -fsS --max-time 10 "http://127.0.0.1:${API_PORT}/api/v1/units/")" || die "GET /api/v1/units/ falhou."
units_count="$(printf '%s' "$units_json" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["results"]))')"
ok "GET /api/v1/units/ → $units_count UPAs"

cat <<EOF

============================================================
 Demonstração pronta (projeto $PROJECT)
============================================================
 API:     http://127.0.0.1:${API_PORT}/api/v1/   (health: ${health_url})
 Postgres: 127.0.0.1:${DB_HOST_PORT} (banco ${POSTGRES_DB_NAME}, usuário ${POSTGRES_USER_NAME})

 Flutter em um Android físico (USB ou depuração sem fio):
   adb reverse tcp:${API_PORT} tcp:${API_PORT}
   cd mobile && flutter run -d <ID_DO_APARELHO> --dart-define=API_BASE_URL=http://127.0.0.1:${API_PORT}
   (liste os aparelhos com: flutter devices)

 Simulador (rode durante a apresentação):
   podman exec ${PROJECT}_api_1 python manage.py simulate_operational_status --unit upa-centro --scenario critical
   podman exec ${PROJECT}_api_1 python manage.py simulate_operational_status --all --scenario baseline
   podman exec ${PROJECT}_api_1 python manage.py show_demo_status

 Atualização automática (DEMO_AUTO_UPDATE=true no .env):
   podman logs -f ${PROJECT}_simulator_1        # acompanhar
   podman stop ${PROJECT}_simulator_1           # pausar sem afetar a API

 Encerrar (mantém banco e volume):  ./scripts/stop-demo.sh
============================================================
EOF
