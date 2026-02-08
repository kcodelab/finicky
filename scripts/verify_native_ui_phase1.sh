#!/bin/bash
set -euo pipefail

REPO_ROOT="/Users/kaaaaai/Documents/PersonalItems/finicky"

echo "[1/2] Go build"
(
  cd "$REPO_ROOT/apps/finicky/src"
  go build ./...
)

echo "[2/2] Wildcard matching tests"
(
  cd "$REPO_ROOT/packages/config-api"
  npm test -- wildcard.test.ts
)

echo "Automated checks passed."
echo "Run manual checklist: $REPO_ROOT/docs/NATIVE_UI_PHASE1_REGRESSION_CHECKLIST.md"
