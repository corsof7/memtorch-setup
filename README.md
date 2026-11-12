# memtorch-setup

Instalación reproducible de [MemTorch](https://github.com/coreylammie/MemTorch) 1.1.6 (CPU) en Linux o WSL, con ejemplos y una guía didáctica en español.

Un solo comando deja listo un entorno con Python 3.9, PyTorch 1.10.2 y MemTorch, aplica los arreglos que necesitan las distribuciones recientes y verifica que todo funcione.

## Requisitos

- **Linux x86_64** o **Windows 10/11 con WSL** (Ubuntu). macOS y ARM no están soportados por los binarios de MemTorch.
- `git` y `curl` (en Ubuntu: `sudo apt install -y git curl`).
- Unos 2 GB libres y conexión a internet.

No hace falta tener Python instalado: el script descarga Python 3.9 aparte, sin tocar el Python del sistema.

### Si estás en Windows

MemTorch **no funciona directamente en Windows** cuando Smart App Control está activo: bloquea su módulo compilado (`DLL load failed ... Control de aplicaciones`). Usa WSL:

1. Abre PowerShell como administrador y ejecuta `wsl --install -d Ubuntu` (solo la primera vez; reinicia si te lo pide).
2. Abre la app **Ubuntu** desde el menú Inicio y sigue los pasos de abajo dentro de ella.

## Instalación

Este repositorio es privado, así que la primera vez en cada PC tienes que iniciar sesión en GitHub dentro de Ubuntu:

```bash
sudo apt install -y gh
gh auth login
```

Elige `GitHub.com`, `HTTPS`, responde `Yes` a usar tus credenciales con Git y sigue el código en el navegador. Después:

```bash
git clone https://github.com/corsof7/memtorch-setup.git
cd memtorch-setup
bash install.sh
```

Tarda unos minutos. Al final debe mostrar `MemTorch instalado correctamente.` y el error medio de una red de prueba (≈ 0.015).

El entorno queda en `~/memtorch-env`. Para otra ubicación:

```bash
MEMTORCH_ENV=/ruta/que/quieras bash install.sh
```

Puedes volver a ejecutar `install.sh` cuando quieras: reutiliza el entorno y repara lo que falte.

## Uso

Cada vez que abras una terminal, activa el entorno:

```bash
source ~/memtorch-env/bin/activate
```

Tu línea de comandos empezará con `(memtorch-env)`. Luego usa `python` normalmente. Para salir: `deactivate`.

O ejecuta un script sin activar nada, con `run.sh`:

```bash
bash run.sh examples/ejemplo.py
bash run.sh examples/characterization.py
```

## Google Colab

[![Abrir en Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/corsof7/memtorch-setup/blob/main/notebooks/memtorch_colab.ipynb)

El notebook [`notebooks/memtorch_colab.ipynb`](notebooks/memtorch_colab.ipynb) instala MemTorch en Colab y ejecuta los dos ejemplos. Colab usa Python 3.12 o más nuevo, así que el notebook crea un entorno aparte con Python 3.9 en `/content/mt` y guarda las gráficas como imágenes para mostrarlas.

Como este repositorio es privado, la primera vez Colab te pedirá autorizar tu cuenta de GitHub. Si el botón no funciona, en Colab ve a **Archivo → Abrir notebook → GitHub**, marca **Incluir repositorios privados** y busca `corsof7/memtorch-setup`.

Colab borra todo al desconectarse: en cada sesión nueva hay que repetir la celda de instalación (2–3 minutos).

## Contenido

| Archivo | Para qué sirve |
| --- | --- |
| `install.sh` | Instala y verifica MemTorch |
| `run.sh` | Ejecuta un script dentro del entorno |
| `GUIA.md` | Guía paso a paso para principiantes en Python |
| `examples/ejemplo.py` | Red ideal frente a red memristiva (crossbars VTEAM) |
| `examples/characterization.py` | Ciclo de histéresis y conmutación bipolar de un memristor |
| `notebooks/memtorch_colab.ipynb` | Instalación y ejemplos en Google Colab |

## Qué arregla `install.sh`

| Problema | Causa | Arreglo |
| --- | --- | --- |
| No hay paquete para tu Python | MemTorch 1.1.6 solo publica binarios para Python 3.7–3.9 | Crea un entorno con Python 3.9 vía [uv](https://github.com/astral-sh/uv) |
| `No matching distribution found for sklearn` | MemTorch declara el paquete obsoleto `sklearn` | Instala `scikit-learn` y MemTorch con `--no-deps` |
| `No module named 'pkg_resources'` | torch 1.10 lo necesita y uv no instala setuptools | Instala `setuptools<70` |
| `cannot enable executable stack` | glibc 2.41+ rechaza bibliotecas antiguas con pila ejecutable | `patchelf --clear-execstack` sobre los `.so` |

## Versiones

| Paquete | Versión |
| --- | --- |
| Python | 3.9 |
| torch | 1.10.2+cpu |
| torchvision | 0.11.3+cpu |
| memtorch-cpu | 1.1.6 |
| numpy | < 1.24 |

Probado en Ubuntu sobre WSL 2 (Windows 11).
