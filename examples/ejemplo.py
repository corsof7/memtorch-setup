"""Primera red memristiva: compara una red ideal con su versión en crossbars VTEAM.

Explicación paso a paso en GUIA.md.
"""
import copy

import torch
import memtorch
from memtorch.mn.Module import patch_model
from memtorch.map.Parameter import naive_map
from memtorch.map.Input import naive_scale

# Paso 3: un memristor
memristor = memtorch.bh.memristor.VTEAM()
print("Resistencia baja  (R_on): ", memristor.r_on, "ohmios")
print("Resistencia alta (R_off):", memristor.r_off, "ohmios")

# Paso 4: la red ideal
torch.manual_seed(0)
red = torch.nn.Sequential(torch.nn.Linear(4, 3))
x = torch.rand(2, 4)
print("Entrada x:")
print(x)
print("Salida de la red ideal:")
print(red(x).detach())

# Paso 5: la red memristiva
red_memristiva = patch_model(
    copy.deepcopy(red),
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
red_memristiva.tune_()

# Paso 6: comparar
ideal = red(x).detach()
memristiva = red_memristiva(x).detach()
print("Salida de la red memristiva:")
print(memristiva)
error = (ideal - memristiva).abs()
print("Error absoluto:")
print(error)
print("Error medio:", round(error.mean().item(), 4))
