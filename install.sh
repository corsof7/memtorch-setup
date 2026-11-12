#!/usr/bin/env bash
# Instalador de MemTorch (CPU) para Linux o WSL (Ubuntu) en x86_64.
#
# Uso:
#   bash install.sh                  # instala en ~/memtorch-env
#   MEMTORCH_ENV=/otra/ruta bash install.sh
#
# Qué hace:
#   1. Instala uv (gestor de Python) si no está.
#   2. Crea un entorno con Python 3.9 (MemTorch 1.1.6 solo tiene binarios para 3.7-3.9).
#   3. Instala PyTorch 1.10.2 CPU, las dependencias y memtorch-cpu 1.1.6.
#   4. Aplica dos arreglos necesarios en distribuciones recientes:
#      - setuptools<70 (torch 1.10 importa pkg_resources)
#      - quita la marca de "pila ejecutable" de las bibliotecas .so
#        (glibc 2.41+ rechaza cargarlas con ese flag)
#   5. Verifica la instalación ejecutando una red memristiva pequeña.
#
# Se puede ejecutar varias veces: si el entorno ya existe, lo reutiliza.

set -euo pipefail

ENV_DIR="${MEMTORCH_ENV:-$HOME/memtorch-env}"
PY_VERSION="3.9"
TORCH_VERSION="1.10.2+cpu"
TORCHVISION_VERSION="0.11.3+cpu"
MEMTORCH_VERSION="1.1.6"
TORCH_INDEX="https://download.pytorch.org/whl/torch_stable.html"

info()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m%s\033[0m\n' "$*"; }
fail()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# --- Comprobaciones previas -------------------------------------------------
[ "$(uname -s)" = "Linux" ] || fail "Este script es para Linux o WSL. En Windows, abre Ubuntu (WSL) y ejecútalo ahí."
[ "$(uname -m)" = "x86_64" ] || fail "MemTorch solo publica binarios para x86_64 (tu equipo: $(uname -m))."
command -v curl >/dev/null || fail "Falta curl. Instálalo con: sudo apt install -y curl"

# --- 1. uv ------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null; then
    info "Instalando uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
ok "uv $(uv --version | awk '{print $2}')"

# --- 2. Entorno con Python 3.9 ----------------------------------------------
if [ -x "$ENV_DIR/bin/python" ]; then
    info "Reutilizando el entorno existente en $ENV_DIR"
else
    info "Creando entorno Python $PY_VERSION en $ENV_DIR"
    uv venv --python "$PY_VERSION" "$ENV_DIR"
fi
PY="$ENV_DIR/bin/python"
pipi() { uv pip install --python "$PY" "$@"; }

# --- 3. Paquetes ------------------------------------------------------------
info "Instalando PyTorch $TORCH_VERSION"
pipi "torch==$TORCH_VERSION" "torchvision==$TORCHVISION_VERSION" -f "$TORCH_INDEX"

info "Instalando dependencias de MemTorch"
# MemTorch declara 'sklearn' (paquete obsoleto que ya no se instala);
# por eso instalamos scikit-learn a mano y MemTorch con --no-deps.
pipi "numpy<1.24" pandas scipy scikit-learn matplotlib seaborn ipython lmfit "setuptools<70" patchelf

info "Instalando memtorch-cpu $MEMTORCH_VERSION"
pipi --no-deps "memtorch-cpu==$MEMTORCH_VERSION"

# --- 4. Quitar la pila ejecutable de las bibliotecas ------------------------
info "Ajustando bibliotecas compartidas (execstack)"
SITE="$("$PY" -c 'import site; print(site.getsitepackages()[0])')"
PATCHELF="$ENV_DIR/bin/patchelf"
count=0
while IFS= read -r -d '' so; do
    "$PATCHELF" --clear-execstack "$so" 2>/dev/null && count=$((count + 1)) || true
done < <(find "$SITE" -name '*.so*' -type f -print0)
ok "$count bibliotecas revisadas"

# --- 5. Verificación --------------------------------------------------------
info "Verificando la instalación"
MPLBACKEND=Agg "$PY" -W ignore - <<'PY'
import copy, torch, memtorch
from memtorch.mn.Module import patch_model
from memtorch.map.Parameter import naive_map
from memtorch.map.Input import naive_scale

torch.manual_seed(0)
red = torch.nn.Sequential(torch.nn.Linear(4, 3))
x = torch.rand(2, 4)
mem = patch_model(copy.deepcopy(red), memristor_model=memtorch.bh.memristor.VTEAM,
                  memristor_model_params={"time_series_resolution": 1e-10},
                  module_parameters_to_patch=[torch.nn.Linear], mapping_routine=naive_map,
                  transistor=True, programming_routine=None, tile_shape=(16, 16),
                  max_input_voltage=0.3, scaling_routine=naive_scale,
                  source_resistance=5, line_resistance=5, ADC_resolution=8, verbose=False)
mem.tune_()
err = (red(x).detach() - mem(x).detach()).abs().mean().item()
print(f"torch {torch.__version__} | error medio red memristiva: {err:.4f}")
assert err < 0.1, "El error es demasiado alto; algo no quedó bien instalado."
PY

ok "
MemTorch instalado correctamente.

Para usarlo, cada vez que abras una terminal:
    source $ENV_DIR/bin/activate
"
