# Funções comuns de start-demo.sh e stop-demo.sh. Não executar diretamente.
# Nenhuma função aqui imprime o valor de segredos (senhas, chave secreta).

PROJECT="rotasaude_demo"
VOLUME="rotasaude_demo_pgdata"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
ENV_FILE="$BACKEND/.env"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[32mOK\033[0m  %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m   %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERRO:\033[0m %s\n' "$*" >&2; exit 1; }

# Descarta linhas que possam conter segredos antes de exibir a saída de comandos.
mask() { grep -viE 'password|secret|senha' || true; }

# Lê CHAVE do .env sem executá-lo (sem `source`). Aceita aspas simples ou duplas.
env_get() {
  local line value
  line="$(grep -E "^$1=" "$ENV_FILE" | tail -n 1 || true)"
  value="${line#*=}"
  value="${value%\"}"; value="${value#\"}"
  value="${value%\'}"; value="${value#\'}"
  printf '%s' "$value"
}

is_true() { case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in true|1|yes|on) return 0 ;; *) return 1 ;; esac; }

require_tools() {
  local tool
  for tool in podman curl; do
    command -v "$tool" >/dev/null 2>&1 || die "'$tool' não encontrado no PATH."
  done
  podman compose version >/dev/null 2>&1 || die "'podman compose' indisponível (instale podman-compose)."
}

# Variáveis exportadas no shell têm prioridade sobre o .env na interpolação do
# podman-compose (e só afetam o serviço db). Removê-las evita que o banco seja criado com
# uma senha, banco ou porta diferente da que a API lê do .env.
neutralize_shell_overrides() {
  local name
  for name in $(compgen -e | grep -E '^(POSTGRES_|DJANGO_|DEMO_|API_|COMPOSE_)' || true); do
    unset "$name"
  done
}

# Sempre explícito: projeto, arquivo de ambiente e diretório do compose.yaml.
compose() { (cd "$BACKEND" && podman compose -p "$PROJECT" --env-file "$ENV_FILE" "$@"); }

# Falha se o .env estiver ausente ou fora do padrão da demonstração.
validate_config() {
  [ -f "$ENV_FILE" ] || die "backend/.env não existe. Rode: cp backend/.env.example backend/.env e ajuste os valores."

  local key
  for key in POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD DJANGO_SECRET_KEY; do
    [ -n "$(env_get "$key")" ] || die "$key está vazio ou ausente em backend/.env."
  done

  is_true "$(env_get DJANGO_DEBUG)" || die "DJANGO_DEBUG precisa ser true na demonstração."
  is_true "$(env_get DEMO_MODE)"    || die "DEMO_MODE precisa ser true na demonstração."

  local declared; declared="$(env_get COMPOSE_PROJECT_NAME)"
  if [ -n "$declared" ] && [ "$declared" != "$PROJECT" ]; then
    die "COMPOSE_PROJECT_NAME no .env é '$declared', mas este ambiente usa '$PROJECT'."
  fi

  API_PORT="$(env_get API_PORT)";               API_PORT="${API_PORT:-8000}"
  DB_HOST_PORT="$(env_get POSTGRES_HOST_PORT)"; DB_HOST_PORT="${DB_HOST_PORT:-5432}"
  POSTGRES_DB_NAME="$(env_get POSTGRES_DB)"
  POSTGRES_USER_NAME="$(env_get POSTGRES_USER)"
  case "$API_PORT$DB_HOST_PORT" in (*[!0-9]*) die "API_PORT e POSTGRES_HOST_PORT devem ser numéricos." ;; esac
  [ "$API_PORT" != "$DB_HOST_PORT" ] || die "API_PORT e POSTGRES_HOST_PORT não podem ser iguais."
}

# 0 se a porta do host estiver ocupada.
port_busy() { ss -ltnH "sport = :$1" 2>/dev/null | grep -q . ; }

# Contêineres existentes do projeto (qualquer estado).
project_containers() { podman ps -a --filter "name=^${PROJECT}_" --format '{{.Names}}'; }
