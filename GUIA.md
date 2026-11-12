# Guía paso a paso: tu primera red memristiva con MemTorch

## Recordatorio: cada vez que vayas a usar MemTorch

MemTorch vive en Ubuntu (WSL), no en Windows. Antes de cualquier cosa, abre la app **Ubuntu** desde el menú Inicio y escribe:

```bash
source ~/memtorch-env/bin/activate
```

Sabrás que funcionó porque tu línea de comandos empieza con `(memtorch-env)`. Si cierras la ventana, tendrás que repetirlo la próxima vez. Para salir del entorno escribe `deactivate`.

## Introducción: qué vamos a hacer y por qué

Al terminar esta guía habrás simulado una red neuronal pequeña ejecutándose sobre hardware de memristores, y entenderás cada línea del código. No necesitas saber Python: lo iremos aprendiendo justo cuando haga falta.

**Qué es un memristor.** Es un componente electrónico cuya resistencia cambia según la corriente que ha pasado por él, y "recuerda" ese valor aunque lo apagues. Piensa en él como una perilla de volumen que se queda donde la dejaste. Tiene dos extremos: resistencia baja (R_on) y resistencia alta (R_off).

**Por qué importa.** Una red neuronal es, en el fondo, muchas multiplicaciones de entradas por pesos. Si guardas cada peso como la conductancia de un memristor y aplicas las entradas como voltajes, la ley de Ohm (I = V × G) hace la multiplicación gratis. Si los colocas en una rejilla llamada *crossbar*, las corrientes se suman solas por la ley de Kirchhoff.

**El problema.** El hardware real no es perfecto: los cables tienen resistencia, los convertidores analógico-digital (ADC) tienen resolución limitada y los dispositivos varían. **MemTorch** es una librería de Python que simula todo esto sobre PyTorch, para que veas cuánto se aleja el resultado del ideal sin fabricar un chip.

**Nuestro plan, en una frase:** creamos una red normal, la convertimos en una red de memristores y comparamos qué responde cada una ante los mismos datos.

## Paso 1: preparar tu espacio de trabajo

Vas a crear una carpeta para tus prácticas y un archivo de Python dentro. Haz esto una sola vez.

1. Abre **Ubuntu** desde el menú Inicio y activa el entorno (ver Recordatorio).
2. Crea una carpeta y entra en ella:

```bash
mkdir -p ~/practicas
cd ~/practicas
```

3. Crea el archivo del ejemplo con el editor `nano` (ponle la extensión `.py` desde el principio):

```bash
nano ejemplo.py
```

4. Escribe o pega el código de cada paso siguiente. En la terminal de Ubuntu se pega con **clic derecho**.
5. Guarda con **Ctrl + O** y luego **Enter**. Sal con **Ctrl + X**.
6. Ejecuta el programa:

```bash
python ejemplo.py
```

**Para profundizar.** `mkdir` significa *make directory* (crear carpeta) y `cd` *change directory* (cambiar de carpeta). El símbolo `~` es tu carpeta personal. Un archivo `.py` es solo texto: Python lo lee de arriba abajo, línea por línea.

**Consejo de profe:** ve añadiendo el código paso a paso y ejecuta después de cada uno. Así, si algo falla, sabes exactamente qué línea fue.

## Paso 2: el Python mínimo que necesitas

Con cinco ideas puedes leer todo el ejemplo. Pruébalas tú: escribe `python` en la terminal para abrir la consola interactiva (aparece `>>>`), teclea cada línea y observa. Sal con `exit()`.

**1. Variables.** Una variable es una etiqueta para un valor. El `=` significa "guarda esto aquí", no "es igual".

```python
voltaje = 0.3
nombre = "VTEAM"
print(voltaje, nombre)   # print muestra valores en pantalla
```

Todo lo que va después de `#` es un comentario: Python lo ignora, es para ti.

**2. Importar librerías.** Python trae poco de fábrica; `import` carga herramientas que otros escribieron. Activar el entorno hace que MemTorch esté *disponible*, pero cada script tiene que *importarlo*. Si lo olvidas verás `NameError: name 'memtorch' is not defined`.

```python
import torch      # PyTorch: cálculo con tensores y redes neuronales
import memtorch   # MemTorch: simulación de memristores
```

Si esto no da error, tu instalación está bien.

**3. Funciones y parámetros.** Una función recibe datos entre paréntesis y devuelve un resultado. Los parámetros pueden ir con nombre, como `tile_shape=(16, 16)`, y eso hace el código más legible.

**4. Tensores.** Un tensor es una tabla de números, la unidad básica de PyTorch. Uno de 2 × 4 tiene 2 filas (2 muestras) y 4 columnas (4 características cada una).

```python
x = torch.rand(2, 4)   # números aleatorios entre 0 y 1
print(x)
print(x.shape)         # torch.Size([2, 4])
```

**5. Una capa `Linear`.** Es la neurona más simple: calcula y = W·x + b, donde W es la matriz de pesos y b el sesgo. `torch.nn.Linear(4, 3)` recibe 4 números y entrega 3, así que W tiene 3 × 4 = 12 pesos. Esos 12 pesos son justo lo que luego guardaremos en memristores.

```python
capa = torch.nn.Linear(4, 3)
print(capa.weight)     # los 12 pesos, elegidos al azar al crearla
```

## Paso 3: conocer a un memristor

Antes de construir la red, conozcamos su ladrillo básico. MemTorch trae varios modelos físicos de memristor; usaremos **VTEAM** (*Voltage ThrEshold Adaptive Memristor*), uno de los más usados en la literatura. Su idea clave: el dispositivo solo cambia de estado si el voltaje supera un umbral.

Escribe esto al inicio de `ejemplo.py`:

```python
import copy
import torch
import memtorch

# Creamos UN memristor con los valores por defecto del modelo VTEAM
memristor = memtorch.bh.memristor.VTEAM()

print("Resistencia baja  (R_on): ", memristor.r_on, "ohmios")
print("Resistencia alta (R_off):", memristor.r_off, "ohmios")
```

Al ejecutar verás:

```
Resistencia baja  (R_on):  50 ohmios
Resistencia alta (R_off): 1000 ohmios
```

**Lee el código como un mapa.** `memtorch.bh.memristor.VTEAM` es una ruta: dentro de `memtorch`, el módulo `bh` (*behavioural*, comportamiento del hardware), dentro `memristor`, y ahí el modelo `VTEAM`. Los paréntesis `()` crean un dispositivo nuevo, y el punto en `memristor.r_on` lee una de sus propiedades.

**Por qué importa.** Un peso de la red tendrá que caber entre estas dos resistencias. En términos de conductancia (G = 1/R), cada memristor solo puede valer entre 1/1000 y 1/50 siemens. MemTorch se encarga de traducir los pesos a ese rango.

Puede aparecer un aviso `SyntaxWarning` de MemTorch. Es un detalle interno de la librería y puedes ignorarlo.

**Extra: ver su comportamiento.** El archivo [`examples/characterization.py`](examples/characterization.py) dibuja el ciclo de histéresis (la "firma" del memristor, una curva en forma de ocho que pasa por el origen) y su conmutación bipolar. Se abren dos ventanas, una tras otra: cierra la primera para ver la segunda.

## Paso 4: construir la red "ideal"

Ahora creamos una red digital normal, que será nuestra referencia. Añade debajo de lo anterior:

```python
# Fijamos la "semilla" del azar para obtener siempre los mismos números
torch.manual_seed(0)

# Una red con una sola capa: 4 entradas -> 3 salidas
red = torch.nn.Sequential(torch.nn.Linear(4, 3))

# Dos muestras de datos, cada una con 4 valores entre 0 y 1
x = torch.rand(2, 4)

print("Entrada x:")
print(x)
print("Salida de la red ideal:")
print(red(x).detach())
```

Ejecuta. Verás una tabla de 2 × 4 (la entrada) y otra de 2 × 3 (la salida): una fila por muestra, tres números por fila.

**Línea por línea.**

- `torch.manual_seed(0)` hace el experimento repetible. Sin ella, cada ejecución daría pesos y datos distintos y no podrías comparar.
- `torch.nn.Sequential(...)` es un contenedor que encadena capas en orden. Aquí solo hay una, pero en redes reales pondrías varias separadas por comas.
- `red(x)` *ejecuta* la red sobre los datos: calcula W·x + b para cada muestra.
- `.detach()` le dice a PyTorch que solo queremos ver el número. Sin él, PyTorch adjunta información de entrenamiento (gradientes) que aquí no necesitamos.

**Pregunta para pensar:** si la capa tuviera 784 entradas y 10 salidas (como en el reconocimiento de dígitos MNIST), ¿cuántos memristores necesitarías para los pesos? Respuesta al final de la guía.

## Paso 5: convertir la red a memristores

La función `patch_model` toma la red ideal y reemplaza cada capa `Linear` por una versión que calcula con crossbars simulados. Primero importa tres herramientas (añádelas junto a los otros `import`, al inicio del archivo):

```python
from memtorch.mn.Module import patch_model
from memtorch.map.Parameter import naive_map
from memtorch.map.Input import naive_scale
```

Y al final del archivo, la conversión:

```python
red_memristiva = patch_model(
    copy.deepcopy(red),                         # copia, para no tocar la original
    memristor_model=memtorch.bh.memristor.VTEAM,
    memristor_model_params={"time_series_resolution": 1e-10},
    module_parameters_to_patch=[torch.nn.Linear],
    mapping_routine=naive_map,
    transistor=True,
    programming_routine=None,
    tile_shape=(16, 16),
    max_input_voltage=0.3,
    scaling_routine=naive_scale,
    source_resistance=5,
    line_resistance=5,
    ADC_resolution=8,
)
```

Al ejecutar verás `Patched Linear(...) -> bh.Linear(...)`: MemTorch te confirma que cambió la capa.

**No olvides calibrar.** Justo debajo de la conversión añade:

```python
red_memristiva.tune_()
```

Los memristores producen corrientes en amperios, no los números de la red. `tune_()` prueba el crossbar con datos aleatorios y aprende el factor que convierte corriente en salida. Verás `Tuned bh.Linear(...) Coefficient of determination: 1.000000`: un valor de 1 significa que la relación es casi perfectamente lineal. **Sin este paso, en mis pruebas el error fue 10 veces mayor.**

**Qué significa cada parámetro.** No hace falta memorizarlos; vuelve a esta tabla cuando experimentes.

| Parámetro | Valor | Qué representa en el hardware |
| --- | --- | --- |
| `copy.deepcopy(red)` | copia de la red | Conservamos la red ideal para comparar después |
| `memristor_model` | VTEAM | El tipo de dispositivo físico (Paso 3) |
| `time_series_resolution` | 1e-10 s | Paso de tiempo con que se simula la física del dispositivo |
| `module_parameters_to_patch` | `[torch.nn.Linear]` | Qué tipo de capas se pasan a memristores |
| `mapping_routine` | `naive_map` | Traduce cada peso a una conductancia entre 1/R_off y 1/R_on, de forma lineal |
| `transistor` | True | Cada memristor lleva un transistor de acceso (celda 1T1R), que aísla cada celda de sus vecinas |
| `programming_routine` | None | Los pesos se escriben de forma ideal, sin simular pulsos de programación |
| `tile_shape` | (16, 16) | Tamaño de cada crossbar físico; matrices grandes se reparten en varios |
| `max_input_voltage` | 0.3 V | Las entradas se convierten en voltajes de hasta 0.3 V |
| `scaling_routine` | `naive_scale` | Cómo se escalan las entradas a ese rango de voltaje |
| `source_resistance` | 5 Ω | Resistencia de la fuente; solo se simula si `transistor=False` |
| `line_resistance` | 5 Ω | Resistencia de los cables; solo se simula si `transistor=False` |
| `ADC_resolution` | 8 bits | El convertidor que lee las corrientes distingue 256 niveles |

Comprobado: con `transistor=True`, cambiar `line_resistance` o `source_resistance` no altera el resultado, porque el transistor aísla cada celda. Para ver su efecto hace falta un crossbar pasivo (`transistor=False`), que además exige una rutina de programación; es un tema más avanzado.

**Un detalle importante:** un memristor no puede tener conductancia negativa, pero los pesos sí son negativos a veces. Por eso MemTorch usa, por defecto, dos columnas de memristores por peso y resta sus corrientes.

## Paso 6: comparar e interpretar

La red memristiva calibrada se equivoca en promedio 0.015 respecto a la ideal, alrededor de un 3.5 % del tamaño típico de las salidas. Añade al final del archivo:

```python
ideal = red(x).detach()
memristiva = red_memristiva(x).detach()

print("Salida de la red memristiva:")
print(memristiva)

error = (ideal - memristiva).abs()   # .abs() = valor absoluto
print("Error absoluto:")
print(error)
print("Error medio:", round(error.mean().item(), 4))
```

Con la semilla 0, esto es lo que se obtiene:

| Muestra | Salida | Red ideal | Red memristiva | Error |
| --- | --- | --- | --- | --- |
| 1 | 1 | -0.6810 | -0.6998 | 0.0188 |
| 1 | 2 | -0.2815 | -0.2769 | 0.0046 |
| 1 | 3 | -0.2735 | -0.2798 | 0.0062 |
| 2 | 1 | -0.8187 | -0.8502 | 0.0316 |
| 2 | 2 | -0.1457 | -0.1286 | 0.0172 |
| 2 | 3 | -0.3058 | -0.3150 | 0.0092 |

**Cómo leerlo.** Las dos redes reciben exactamente los mismos datos y pesos. La diferencia viene solo del hardware simulado: los pesos se comprimen al rango de conductancias del VTEAM, las entradas se convierten en voltajes y las corrientes se reconvierten en números.

**Lo que importa en una red real** no es el número exacto, sino si la decisión final cambia. En un clasificador se elige la salida más alta (la menos negativa):

- **Muestra 2:** ambas redes eligen la salida 2 (-0.1457 frente a -0.1286). La decisión se mantiene.
- **Muestra 1:** la red ideal elige la salida 3 (-0.2735), pero la memristiva elige la salida 2 (-0.2769). La decisión **cambia**.

¿Por qué? En la red ideal las salidas 2 y 3 de la muestra 1 estaban separadas por solo 0.008, menos que el error del hardware. Esta es la lección central de la computación analógica: un error pequeño basta para cambiar la respuesta cuando la red está indecisa.

**Nuevas palabras de Python:** `.mean()` calcula el promedio de todo el tensor, `.item()` lo convierte en un número normal y `round(n, 4)` lo redondea a 4 decimales.

## El script completo

Está en [`examples/ejemplo.py`](examples/ejemplo.py). Úsalo para comparar si algo no te funciona. Desde la carpeta del repositorio:

```bash
bash run.sh examples/ejemplo.py
```

## Ejercicios para practicar

Cambia una sola cosa cada vez, ejecuta y anota el error medio. Así se trabaja en un laboratorio.

- [ ] Comenta la línea `red_memristiva.tune_()` poniéndole `#` delante. ¿Cuánto crece el error?
- [ ] Cambia la semilla `torch.manual_seed(0)` por 1, 2 y 3. ¿La decisión cambia en alguna muestra?
- [ ] Usa más datos: `x = torch.rand(100, 4)`. ¿En cuántas de las 100 muestras cambia la decisión? Pista: `(ideal.argmax(dim=1) != memristiva.argmax(dim=1)).sum()`.
- [ ] Prueba `max_input_voltage=0.1` y `max_input_voltage=1.0`. ¿Qué voltaje funciona mejor?
- [ ] Haz la capa más grande, `torch.nn.Linear(64, 10)` con `x = torch.rand(2, 64)`, y prueba `tile_shape=(8, 8)`. ¿En cuántos crossbars se reparte?

**Respuesta a la pregunta del Paso 4:** 784 × 10 = 7 840 pesos. Como MemTorch usa dos columnas por peso para los negativos, serían 15 680 memristores.

## Errores comunes y cómo resolverlos

| Mensaje que ves | Causa probable | Solución |
| --- | --- | --- |
| `NameError: name 'memtorch' is not defined` | Falta `import memtorch` en el script | Añádelo en la primera línea |
| `ModuleNotFoundError: No module named 'torch'` | No activaste el entorno | Ejecuta `source ~/memtorch-env/bin/activate` |
| `python: command not found` | Estás fuera del entorno | Activa el entorno; usa `python`, no `python3` |
| `IndentationError` | Espacios de más al inicio de una línea | Las líneas de nivel superior empiezan sin espacios |
| `SyntaxError` | Falta un paréntesis, coma o comilla | Revisa la línea indicada y la anterior |
| `NameError: name 'red' is not defined` | Usas una variable antes de crearla | Mantén el orden de los pasos |
| `SyntaxWarning: "is not" with a literal` | Detalle interno de MemTorch | Ignóralo; no afecta |
| `DLL load failed` en Windows | Smart App Control bloquea MemTorch | Usa siempre Ubuntu (WSL) |
