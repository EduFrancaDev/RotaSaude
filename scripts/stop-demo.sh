#!/usr/bin/env bash
# Para os contêineres do projeto `rotasaude_demo` (API e Postgres).
#
# Só usa `stop`: contêineres, banco, tabelas e o volume `rotasaude_demo_pgdata` são
# preservados. Nunca executa `down -v`, `volume rm`/`prune` ou `system prune`, e não
# toca em contêineres de outros projetos/worktrees.
#
# Uso: ./scripts/stop-demo.sh
set -euo pipefail

# shellcheck source=scripts/_demo_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_demo_common.sh"

case "${1:-}" in
  "") ;;
  -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "Argumento desconhecido: $1 (use --help)." ;;
esac

require_tools
neutralize_shell_overrides
[ -f "$ENV_FILE" ] || die "backend/.env não existe; nada a parar com segurança."

info "Parando o projeto $PROJECT (sem remover contêineres nem volumes)"
if [ -z "$(project_containers)" ]; then
  ok "nenhum contêiner de $PROJECT encontrado; nada a fazer"
else
  # Para pelos nomes (apenas ${PROJECT}_*), independentemente do diretório atual.
  for name in $(project_containers); do
    # Postgres: prazo generoso para encerrar limpo. API: o runserver sob `sh -c` não repassa o
    # SIGTERM e não guarda estado, então um prazo curto evita esperar à toa.
    case "$name" in *_db_*) grace=30 ;; *) grace=2 ;; esac
    podman stop -t "$grace" "$name" >/dev/null 2>&1 && ok "parado: $name"
  done
fi

if podman volume exists "$VOLUME" 2>/dev/null; then
  ok "volume $VOLUME preservado (dados do banco intactos)"
else
  warn "volume $VOLUME não existe (a demonstração ainda não foi iniciada)"
fi
echo
echo "Para retomar: ./scripts/start-demo.sh"
