#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PROJECT_ROOT="$(/usr/bin/time -p pwd)"
/usr/bin/time -p echo "project root: $PROJECT_ROOT"
/usr/bin/time -p mkdir -p "$PROJECT_ROOT/dist"
if /usr/bin/time -p test -f "$PROJECT_ROOT/package.json"; then
  if /usr/bin/time -p test -f "$PROJECT_ROOT/package-lock.json"; then
    /usr/bin/time -p npm ci --no-audit --no-fund
  else
    /usr/bin/time -p npm install --no-audit --no-fund
  fi
fi
if /usr/bin/time -p test -f "$PROJECT_ROOT/index.html"; then
  /usr/bin/time -p cp -u "$PROJECT_ROOT/index.html" "$PROJECT_ROOT/dist/index.html"
fi
/usr/bin/time -p test -f "$PROJECT_ROOT/dist/index.html"
DIST_DIR="$PROJECT_ROOT/dist"
/usr/bin/time -p echo "serving $DIST_DIR on port ${PORT:-3000}"
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
/usr/bin/time -p mkdir -p "$WEB_DIR"
/usr/bin/time -p env PROJECT_ROOT="$PROJECT_ROOT" DIST_DIR="$DIST_DIR" WEB_DIR="$WEB_DIR" python3 -c "import json,os; open(os.path.join(os.environ['WEB_DIR'],'deployment-output.json'),'w').write(json.dumps({'project':os.environ['PROJECT_ROOT'],'directory':os.environ['DIST_DIR']}))"
/usr/bin/time -p cat "$WEB_DIR/deployment-output.json"
/usr/bin/time -p echo "deployment-output written"
PORT="${PORT:-3000}"
export PORT
exec /usr/bin/time -p python3 -m http.server "$PORT" --directory "$DIST_DIR" --bind 0.0.0.0
