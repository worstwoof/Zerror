#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON_CMD=()
if [[ -n "${PYTHON:-}" ]]; then
  PYTHON_CMD=("$PYTHON")
else
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD=("python3")
  elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD=("python")
  elif command -v py >/dev/null 2>&1; then
    PYTHON_CMD=("py" "-3")
  else
    echo "No Python interpreter found. Set PYTHON=/path/to/python." >&2
    exit 127
  fi
fi

"${PYTHON_CMD[@]}" scripts/test_config_guards.py
"${PYTHON_CMD[@]}" scripts/test_auth_guards.py
"${PYTHON_CMD[@]}" scripts/test_object_storage_guards.py
"${PYTHON_CMD[@]}" scripts/test_file_route_guards.py
"${PYTHON_CMD[@]}" scripts/test_upload_route_guards.py
"${PYTHON_CMD[@]}" scripts/test_app_state_service_guards.py
"${PYTHON_CMD[@]}" scripts/test_analysis_quality_guards.py
"${PYTHON_CMD[@]}" scripts/test_render_diagnostics.py
"${PYTHON_CMD[@]}" -m compileall -q backend ai_engine scripts
