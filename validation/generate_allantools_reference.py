#!/usr/bin/env python3
"""
Generate reference data using AllanTools for StabLab.jl validation.
This script creates a comprehensive set of reference values that can be
compared against Julia implementations.
"""

import numpy as np
import allantools
import json
import sys
from pathlib import Path

def generate_test_data(N=10000, seed=42):
    """Generate reproducible test data"""
    np.random.seed(seed)
    
    # White phase noise - cumulative sum of white noise
    phase_white = np.cumsum(np.random.randn(N)) * 1e-9
    
    # Flicker frequency noise (approximate)
    freq_flicker = np.random.randn(N) / np.sqrt(np.arange(1, N+1)) * 1e-11
    phase_flicker = np.cumsum(np.cumsum(freq_flicker))
    
    # Random walk frequency
    freq_rw = np.cumsum(np.random.randn(N)) * 1e-12
    phase_rw = np.cumsum(np.cumsum(freq_rw))
    
    return {
        'white_phase': phase_white,
        'flicker_freq': phase_flicker, 
        'rw_freq': phase_rw
    }

def compute_allantools_deviations(phase_data, tau0=1.0):
    """Compute all available deviations using AllanTools"""
    results = {}
    
    # Standard tau list (octave-spaced)
    rate = 1.0 / tau0
    N = len(phase_data)
    max_tau = N // 10  # Conservative limit
    taus = tau0 * np.logspace(0, np.log10(max_tau), 20, dtype=int)
    taus = np.unique(taus)  # Remove duplicates
    
    print(f"Computing AllanTools deviations for N={N} points...")
    print(f"Tau range: {taus[0]} to {taus[-1]} seconds ({len(taus)} points)")
    
    try:
        # Allan deviation (overlapping)
        (t_adev, adev, adev_err, n_adev) = allantools.oadev(phase_data, rate=rate, data_type="phase", taus=taus)
        results['adev'] = {'tau': t_adev.tolist(), 'dev': adev.tolist(), 'err': adev_err.tolist(), 'n': n_adev.tolist()}
        print(f"  ADEV: {len(t_adev)} points")
    except Exception as e:
        print(f"  ADEV failed: {e}")
        
    try:
        # Modified Allan deviation
        (t_mdev, mdev, mdev_err, n_mdev) = allantools.mdev(phase_data, rate=rate, data_type="phase", taus=taus)
        results['mdev'] = {'tau': t_mdev.tolist(), 'dev': mdev.tolist(), 'err': mdev_err.tolist(), 'n': n_mdev.tolist()}
        print(f"  MDEV: {len(t_mdev)} points")
    except Exception as e:
        print(f"  MDEV failed: {e}")
        
    try:
        # Time deviation
        (t_tdev, tdev, tdev_err, n_tdev) = allantools.tdev(phase_data, rate=rate, data_type="phase", taus=taus)
        results['tdev'] = {'tau': t_tdev.tolist(), 'dev': tdev.tolist(), 'err': tdev_err.tolist(), 'n': n_tdev.tolist()}
        print(f"  TDEV: {len(t_tdev)} points")
    except Exception as e:
        print(f"  TDEV failed: {e}")
        
    try:
        # Hadamard deviation (overlapping)
        (t_hdev, hdev, hdev_err, n_hdev) = allantools.ohdev(phase_data, rate=rate, data_type="phase", taus=taus)
        results['hdev'] = {'tau': t_hdev.tolist(), 'dev': hdev.tolist(), 'err': hdev_err.tolist(), 'n': n_hdev.tolist()}
        print(f"  HDEV: {len(t_hdev)} points")
    except Exception as e:
        print(f"  HDEV failed: {e}")
        
    try:
        # Total deviation
        (t_totdev, totdev, totdev_err, n_totdev) = allantools.totdev(phase_data, rate=rate, data_type="phase", taus=taus)
        results['totdev'] = {'tau': t_totdev.tolist(), 'dev': totdev.tolist(), 'err': totdev_err.tolist(), 'n': n_totdev.tolist()}
        print(f"  TOTDEV: {len(t_totdev)} points")
    except Exception as e:
        print(f"  TOTDEV failed: {e}")
        
    try:
        # Modified total deviation
        (t_mtotdev, mtotdev, mtotdev_err, n_mtotdev) = allantools.mtotdev(phase_data, rate=rate, data_type="phase", taus=taus)
        results['mtotdev'] = {'tau': t_mtotdev.tolist(), 'dev': mtotdev.tolist(), 'err': mtotdev_err.tolist(), 'n': n_mtotdev.tolist()}
        print(f"  MTOTDEV: {len(t_mtotdev)} points")
    except Exception as e:
        print(f"  MTOTDEV failed: {e}")
        
    # Time interval error functions (use smaller tau range)
    tie_taus = taus[taus <= 50]  # TIE/MTIE work better with smaller taus
    
    try:
        # Time Interval Error
        (t_tie, tie, tie_err, n_tie) = allantools.tie(phase_data, rate=rate, data_type="phase", taus=tie_taus)
        results['tie'] = {'tau': t_tie.tolist(), 'dev': tie.tolist(), 'err': tie_err.tolist(), 'n': n_tie.tolist()}
        print(f"  TIE: {len(t_tie)} points")
    except Exception as e:
        print(f"  TIE failed: {e}")
        
    try:
        # Maximum Time Interval Error
        (t_mtie, mtie, mtie_err, n_mtie) = allantools.mtie(phase_data, rate=rate, data_type="phase", taus=tie_taus)
        results['mtie'] = {'tau': t_mtie.tolist(), 'dev': mtie.tolist(), 'err': mtie_err.tolist(), 'n': n_mtie.tolist()}
        print(f"  MTIE: {len(t_mtie)} points")
    except Exception as e:
        print(f"  MTIE failed: {e}")
        
    try:
        # Parabolic deviation
        (t_pdev, pdev, pdev_err, n_pdev) = allantools.pdev(phase_data, rate=rate, data_type="phase", taus=taus)
        results['pdev'] = {'tau': t_pdev.tolist(), 'dev': pdev.tolist(), 'err': pdev_err.tolist(), 'n': n_pdev.tolist()}
        print(f"  PDEV: {len(t_pdev)} points")
    except Exception as e:
        print(f"  PDEV failed: {e}")
        
    return results

def main():
    print("Generating AllanTools reference data...")
    
    # Generate test datasets
    datasets = generate_test_data()
    
    # Output directory
    output_dir = Path("validation")
    output_dir.mkdir(exist_ok=True)
    
    # Process each dataset
    for dataset_name, phase_data in datasets.items():
        print(f"\n{'='*50}")
        print(f"Processing {dataset_name} dataset")
        print(f"{'='*50}")
        
        # Compute deviations
        results = compute_allantools_deviations(phase_data)
        
        # Save results
        output_file = output_dir / f"allantools_reference_{dataset_name}.json"
        
        # Create metadata
        metadata = {
            'dataset': dataset_name,
            'N': len(phase_data),
            'tau0': 1.0,
            'seed': 42,
            'allantools_version': allantools.__version__,
            'data_type': 'phase',
            'data_range': [float(np.min(phase_data)), float(np.max(phase_data))]
        }
        
        output_data = {
            'metadata': metadata,
            'results': results
        }
        
        with open(output_file, 'w') as f:
            json.dump(output_data, f, indent=2)
            
        print(f"Saved: {output_file}")
        print(f"Functions computed: {list(results.keys())}")
    
    # Also save the raw test data for Julia to use
    test_data_file = output_dir / "test_datasets.json"
    with open(test_data_file, 'w') as f:
        # Convert numpy arrays to lists for JSON serialization
        datasets_serializable = {
            name: data.tolist() for name, data in datasets.items()
        }
        json.dump({
            'metadata': {'N': len(list(datasets.values())[0]), 'tau0': 1.0, 'seed': 42},
            'datasets': datasets_serializable
        }, f, indent=2)
    
    print(f"\nSaved test datasets: {test_data_file}")
    print("AllanTools reference generation complete!")

if __name__ == "__main__":
    main()