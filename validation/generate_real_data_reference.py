#!/usr/bin/env python3
"""
Generate reference data using AllanTools on real test data files.
Uses the actual data files that the user knows well: 6krb25apr.txt, 6krbsnip.txt, mx.w10.pem7
"""

import numpy as np
import allantools
import json
import sys
from pathlib import Path
import gzip

def load_phase_data(filename):
    """Load phase data from various file formats"""
    filepath = Path(filename)
    
    print(f"Loading {filepath.name}...")
    
    # Handle compressed files
    if filepath.suffix == '.gz':
        with gzip.open(filepath, 'rt') as f:
            lines = f.readlines()
    else:
        with open(filepath, 'r') as f:
            lines = f.readlines()
    
    # Parse data (assuming simple text format with one value per line)
    phase_data = []
    for line in lines:
        line = line.strip()
        if line and not line.startswith('#') and not line.startswith('%'):
            try:
                # Try to parse as float
                value = float(line.split()[0])  # Take first column if multiple
                phase_data.append(value)
            except (ValueError, IndexError):
                continue
    
    if not phase_data:
        raise ValueError(f"No valid data found in {filepath}")
    
    phase_data = np.array(phase_data)
    print(f"  Loaded {len(phase_data)} data points")
    print(f"  Range: [{phase_data.min():.3e}, {phase_data.max():.3e}]")
    
    return phase_data

def compute_allantools_deviations(phase_data, tau0=1.0, dataset_name=""):
    """Compute all available deviations using AllanTools"""
    results = {}
    
    # Standard tau list (octave-spaced, conservative for real data)
    rate = 1.0 / tau0
    N = len(phase_data)
    max_tau = min(N // 20, 1000)  # Conservative limit for real data
    taus = tau0 * np.unique(np.logspace(0, np.log10(max_tau), 25, dtype=int))
    
    print(f"Computing AllanTools deviations for {dataset_name}...")
    print(f"N={N} points, tau range: {taus[0]} to {taus[-1]} seconds ({len(taus)} points)")
    
    # List of functions to test (only use functions that exist in AllanTools)
    allantools_functions = [
        ('adev', allantools.oadev, "Allan Deviation (Overlapping)"),
        ('mdev', allantools.mdev, "Modified Allan Deviation"), 
        ('tdev', allantools.tdev, "Time Deviation"),
        ('hdev', allantools.ohdev, "Hadamard Deviation (Overlapping)"),
        ('totdev', allantools.totdev, "Total Deviation"),
        ('mtotdev', allantools.mtotdev, "Modified Total Deviation"),
        ('pdev', allantools.pdev, "Parabolic Deviation")
    ]
    
    # Check if TIE/MTIE functions exist and add them
    if hasattr(allantools, 'tie'):
        allantools_functions.append(('tie', allantools.tie, "Time Interval Error"))
    if hasattr(allantools, 'mtie'):
        allantools_functions.append(('mtie', allantools.mtie, "Maximum Time Interval Error"))
    
    for func_name, func, description in allantools_functions:
        try:
            # Use appropriate tau range for each function
            if func_name in ['tie', 'mtie']:
                # TIE/MTIE work better with smaller taus
                test_taus = taus[taus <= min(100, max_tau//2)]
            else:
                test_taus = taus
            
            print(f"  Computing {func_name} ({description})...")
            (t_vals, dev_vals, err_vals, n_vals) = func(phase_data, rate=rate, data_type="phase", taus=test_taus)
            
            results[func_name] = {
                'tau': t_vals.tolist(),
                'dev': dev_vals.tolist(), 
                'err': err_vals.tolist(),
                'n': n_vals.tolist(),
                'description': description
            }
            print(f"    ✓ {func_name}: {len(t_vals)} points")
            
        except Exception as e:
            print(f"    ✗ {func_name} failed: {e}")
            continue
    
    return results

def main():
    print("Generating AllanTools reference data for real test datasets...")
    
    # Data file locations (relative to validation directory)
    data_dir = Path("data")
    test_files = [
        ("6krb25apr", data_dir / "6krb25apr.txt", 1.0, "Rubidium clock full dataset"),
        ("6krbsnip", data_dir / "6krbsnip.txt", 1.0, "Rubidium clock snippet"),
        ("mx_w10_pem7", data_dir / "mx.w10.pem7", 1.0, "GPS receiver data")
    ]
    
    # Output directory
    output_dir = Path(".")
    output_dir.mkdir(exist_ok=True)
    
    all_results = {}
    
    # Process each dataset
    for dataset_name, filepath, tau0, description in test_files:
        print(f"\n{'='*60}")
        print(f"Processing {dataset_name}: {description}")
        print(f"{'='*60}")
        
        try:
            # Load phase data
            if not filepath.exists():
                print(f"Warning: File not found: {filepath}")
                print("Skipping this dataset...")
                continue
            
            phase_data = load_phase_data(filepath)
            
            # Compute deviations
            results = compute_allantools_deviations(phase_data, tau0, dataset_name)
            
            if not results:
                print(f"Warning: No results computed for {dataset_name}")
                continue
            
            # Save individual results file
            output_file = output_dir / f"allantools_reference_{dataset_name}.json"
            
            # Create metadata
            metadata = {
                'dataset': dataset_name,
                'description': description,
                'filepath': str(filepath),
                'N': len(phase_data),
                'tau0': tau0,
                'allantools_version': allantools.__version__,
                'data_type': 'phase',
                'data_range': [float(np.min(phase_data)), float(np.max(phase_data))],
                'data_statistics': {
                    'mean': float(np.mean(phase_data)),
                    'std': float(np.std(phase_data)),
                    'duration_seconds': len(phase_data) * tau0
                }
            }
            
            output_data = {
                'metadata': metadata,
                'results': results
            }
            
            with open(output_file, 'w') as f:
                json.dump(output_data, f, indent=2)
                
            print(f"Saved: {output_file}")
            print(f"Functions computed: {list(results.keys())}")
            
            # Store in combined results
            all_results[dataset_name] = output_data
            
            # Save raw data for Julia (first 10000 points to keep reasonable size)
            max_points = 10000
            if len(phase_data) > max_points:
                phase_subset = phase_data[:max_points]
                print(f"Note: Saved first {max_points} points of {len(phase_data)} for Julia comparison")
            else:
                phase_subset = phase_data
            
            data_file = output_dir / f"phase_data_{dataset_name}.json"
            with open(data_file, 'w') as f:
                json.dump({
                    'phase_data': phase_subset.tolist(),
                    'tau0': tau0,
                    'N_original': len(phase_data),
                    'N_subset': len(phase_subset),
                    'dataset': dataset_name,
                    'description': description
                }, f, indent=2)
            print(f"Saved phase data: {data_file}")
            
        except Exception as e:
            print(f"Error processing {dataset_name}: {e}")
            continue
    
    # Create combined reference file
    if all_results:
        combined_file = output_dir / "all_datasets_allantools_reference.json"
        with open(combined_file, 'w') as f:
            json.dump(all_results, f, indent=2)
        print(f"\nSaved combined results: {combined_file}")
    
    print("\n" + "="*60)
    print("AllanTools reference generation complete!")
    print("="*60)
    print(f"Processed datasets: {list(all_results.keys())}")
    print("Generated files:")
    for file in output_dir.glob("*reference*.json"):
        print(f"  {file.name}")
    for file in output_dir.glob("phase_data_*.json"):
        print(f"  {file.name}")

if __name__ == "__main__":
    main()