"""Caracterización de un memristor VTEAM: ciclo de histéresis y conmutación bipolar.

Abre dos ventanas con gráficas, una después de otra: cierra la primera para ver la segunda.
"""
import memtorch

reference_memristor = memtorch.bh.memristor.VTEAM
reference_memristor_params = {"time_series_resolution": 1e-10}
memristor = reference_memristor(**reference_memristor_params)
memristor.plot_hysteresis_loop()
memristor.plot_bipolar_switching_behaviour()
