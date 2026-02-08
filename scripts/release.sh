./scripts/build.sh
mkdir -p dist
if [ ! -f .env ]; then
  echo ".env file not found. Create it from .env.example before releasing."
  exit 1
fi
set -a
. ./.env
set +a
gon scripts/gon-config.json
