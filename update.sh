#!/usr/bin/env bash
# Haalt de nieuwste code op voor vehictory_backend + vehictory_frontend, bouwt de
# Docker-images opnieuw en herstart de stack (postgres + api + frontend).
#
# Verwachte layout (repo's naast elkaar geclonet):
#   vehictory/
#     vehictory_backend/
#     vehictory_frontend/
#     vehictory_deploy/    <- dit script
#
# Gebruik:
#   ./update.sh            update + herstart alles
#   ./update.sh --no-pull   sla 'git pull' over, bouw/herstart alleen opnieuw
#   ./update.sh --logs      toon na het herstarten ook de laatste logregels

set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$DEPLOY_DIR")"
REPOS=(vehictory_backend vehictory_frontend)

DO_PULL=true
SHOW_LOGS=false
for arg in "$@"; do
  case "$arg" in
    --no-pull) DO_PULL=false ;;
    --logs) SHOW_LOGS=true ;;
    *) echo "Onbekende optie: $arg" >&2; exit 1 ;;
  esac
done

if [ ! -f "$DEPLOY_DIR/.env" ]; then
  echo "Fout: $DEPLOY_DIR/.env ontbreekt. Kopieer .env.example naar .env en vul de waarden in." >&2
  exit 1
fi

if $DO_PULL; then
  echo "==> Nieuwste code ophalen..."
  for repo in "${REPOS[@]}"; do
    repo_dir="$ROOT_DIR/$repo"
    if [ ! -d "$repo_dir/.git" ]; then
      echo "Waarschuwing: $repo_dir is geen git-repo (of bestaat niet), overslaan." >&2
      continue
    fi
    echo "--- $repo ---"
    git -C "$repo_dir" fetch --quiet
    branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)"
    git -C "$repo_dir" pull --ff-only origin "$branch"
  done
else
  echo "==> --no-pull opgegeven, git pull overgeslagen."
fi

cd "$DEPLOY_DIR"

echo "==> Images bouwen..."
docker compose build

echo "==> Database-migraties worden automatisch toegepast bij het opstarten van de API (Program.cs: db.Database.Migrate())."

echo "==> Stack herstarten..."
docker compose up -d --remove-orphans

echo "==> Ongebruikte images opruimen..."
docker image prune -f >/dev/null

echo "==> Statuscontrole..."
sleep 3
docker compose ps

API_PORT="$(grep -E '^API_PORT=' .env | cut -d= -f2 || echo 5080)"
API_PORT="${API_PORT:-5080}"
if curl -fsS "http://localhost:${API_PORT}/api/health" >/dev/null 2>&1; then
  echo "API bereikbaar op poort ${API_PORT}."
else
  echo "Waarschuwing: kon API niet bereiken op http://localhost:${API_PORT}/api/health" >&2
fi

if $SHOW_LOGS; then
  docker compose logs --tail=50
fi

echo "==> Klaar."
