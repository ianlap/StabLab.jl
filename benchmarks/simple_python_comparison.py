#!/usr/bin/env python3
"""
Simple Python validation script for StabLab.jl time error functions
Run this to generate reference data from AllanTools for comparison
"""

import numpy as np
import sys
sys.path.insert(0, '/Users/ianlapinski/Desktop/masterclock-kflab/allantools/allantools')
import allantools as at
import json

# Set random seed for reproducibility
np.random.seed(42)

# Generate test data
N = 10000
tau0 = 1.0
print(f"Generating {N} point test dataset...")

# White phase noise
phase_data = np.cumsum(np.random.randn(N) * 1e-9)

print("Computing AllanTools reference values...")

# Compute TIE with AllanTools
try:
    tau_tie, tie_dev, tie_err, tie_n = at.tierms(phase_data, rate=1/tau0, data_type="phase", taus="octave")
    tie_results = {
        'tau': tau_tie.tolist(),
        'deviation': tie_dev.tolist(),
        'error': tie_err.tolist(),
        'n': tie_n.tolist()
    }
    print(f"TIE computed: {len(tau_tie)} points")
except Exception as e:
    print(f"TIE error: {e}")
    tie_results = None

# Compute MTIE with AllanTools
try:
    tau_mtie, mtie_dev, mtie_err, mtie_n = at.mtie(phase_data, rate=1/tau0, data_type="phase", taus="octave")
    mtie_results = {
        'tau': tau_mtie.tolist(),
        'deviation': mtie_dev.tolist(),
        'error': mtie_err.tolist(),
        'n': mtie_n.tolist()
    }
    print(f"MTIE computed: {len(tau_mtie)} points")
except Exception as e:
    print(f"MTIE error: {e}")
    mtie_results = None

# Compute PDEV with AllanTools
try:
    tau_pdev, pdev_dev, pdev_err, pdev_n = at.pdev(phase_data, rate=1/tau0, data_type="phase", taus="octave")
    pdev_results = {
        'tau': tau_pdev.tolist(),
        'deviation': pdev_dev.tolist(),
        'error': pdev_err.tolist(),
        'n': pdev_n.tolist()
    }
    print(f"PDEV computed: {len(tau_pdev)} points")
except Exception as e:
    print(f"PDEV error: {e}")
    pdev_results = None

# Save reference data and test data
reference_data = {
    'phase_data': phase_data.tolist(),
    'tau0': tau0,
    'N': N,
    'tie': tie_results,
    'mtie': mtie_results,
    'pdev': pdev_results
}

with open('allantools_reference.json', 'w') as f:
    json.dump(reference_data, f, indent=2)

print("\nAllanTools reference data saved to 'allantools_reference.json'")
print("Now run Julia comparison script to validate StabLab.jl results")

# Print some sample values
if tie_results:
    print(f"\nTIE sample values:")
    for i in [0, 2, 4]:
        if i < len(tie_results['tau']):
            print(f"  τ={tie_results['tau'][i]:.1f}s: TIE={tie_results['deviation'][i]:.3e}")

if mtie_results:
    print(f"\nMTIE sample values:")
    for i in [0, 2, 4]:
        if i < len(mtie_results['tau']):
            print(f"  τ={mtie_results['tau'][i]:.1f}s: MTIE={mtie_results['deviation'][i]:.3e}")

if pdev_results:
    print(f"\nPDEV sample values:")
    for i in [0, 2, 4]:
        if i < len(pdev_results['tau']):
            print(f"  τ={pdev_results['tau'][i]:.1f}s: PDEV={pdev_results['deviation'][i]:.3e}")