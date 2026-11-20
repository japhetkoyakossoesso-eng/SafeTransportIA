#!/bin/sh
# Démarre la base, l'API et le site, puis ouvre le navigateur
set -e
cd "$(dirname "$0")/.."
test -f .env || cp .env.example .env

PORT=$(grep -s '^WEB_PORT=' .env | cut -d= -f2)
URL="http://localhost:${PORT:-5173}"

docker compose up -d --build web

printf "Attente de l'API"
essais=0
until curl -fs "$URL/api/v1/health" > /dev/null; do
  essais=$((essais + 1))
  if [ "$essais" -gt 90 ]; then
    echo
    echo "L'API ne répond pas. Regarde : docker compose logs api"
    exit 1
  fi
  printf "."
  sleep 2
done

echo
echo
echo "  SafeTransportIA est prêt : $URL"
echo "  Connexion : analyste.demo / demo"
echo "  Pour tout arrêter : make down"
echo

if command -v open > /dev/null; then
  open "$URL"
elif command -v xdg-open > /dev/null; then
  xdg-open "$URL" > /dev/null 2>&1
fi
