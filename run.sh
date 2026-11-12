#!/usr/bin/env bash
# Ejecuta un script de Python dentro del entorno de MemTorch sin tener que activarlo.
#
# Uso:
#   bash run.sh examples/ejemplo.py
#   bash run.sh examples/characterization.py

set -euo pipefail

ENV_DIR="${MEMTORCH_ENV:-$HOME/memtorch-env}"

if [ ! -x "$ENV_DIR/bin/python" ]; then
    echo "No encuentro el entorno en $ENV_DIR. Ejecuta primero: bash install.sh" >&2
    exit 1
fi
if [ $# -lt 1 ]; then
    echo "Uso: bash run.sh <script.py> [argumentos...]" >&2
    exit 1
fi

# -W ignore oculta un SyntaxWarning interno de MemTorch que no afecta.
exec "$ENV_DIR/bin/python" -W ignore "$@"
