#!/usr/bin/env python3
"""
Generate AllanTools reference data for 6krbsnip.txt (100k points) with timing measurements
"""

import numpy as np
import allantools
import json
import matplotlib.pyplot as plt
import time
from pathlib import Path

def main():
    print("Generating AllanTools reference for 6krbsnip.txt with octave spacing")
    print("="*60)
    
    # Load data
    data_file = Path("data/6krbsnip.txt")
    print(f"Loading {data_file}...")
    
    data_matrix = np.loadtxt(data_file)
    phase_data = data_matrix[:, 1]  # Phase data is in column 2 (Python 0-indexed)
    tau0 = 1.0
    rate = 1.0 / tau0
    N = len(phase_data)
    
    print(f"Loaded {N} phase data points")
    print(f"Data range: [{phase_data.min():.6f}, {phase_data.max():.6f}]")
    print(f"Sampling rate: {rate} Hz, tau0 = {tau0} s")
    
    # Use octave spacing like MATLAB/Julia default
    max_m = N // 10  # Conservative limit
    m_values = []
    m = 1
    while m <= max_m:
        m_values.append(m)
        m *= 2  # Octave spacing
    
    taus = np.array(m_values) * tau0
    print(f"Using octave spacing: m = {m_values}")
    print(f"Tau range: {taus[0]} to {taus[-1]} seconds ({len(taus)} points)")
    
    # Compute all available functions with timing
    allantools_results = {}
    timing_results = {}
    
    functions_to_test = [
        ('adev', allantools.oadev, "Allan Deviation (Overlapping)"),
        ('mdev', allantools.mdev, "Modified Allan Deviation"),
        ('tdev', allantools.tdev, "Time Deviation"), 
        ('hdev', allantools.ohdev, "Hadamard Deviation (Overlapping)"),
        ('totdev', allantools.totdev, "Total Deviation"),
        ('mtotdev', allantools.mtotdev, "Modified Total Deviation"),
        ('pdev', allantools.pdev, "Parabolic Deviation")
    ]
    
    print(f"\n{'='*60}")
    print("Computing AllanTools deviations with timing...")
    print(f"{'='*60}")
    
    total_start_time = time.time()
    
    for func_name, func, description in functions_to_test:
        try:
            print(f"  {func_name.upper():8}: ", end="", flush=True)
            
            start_time = time.time()
            (t_vals, dev_vals, err_vals, n_vals) = func(
                phase_data, rate=rate, data_type="phase", taus=taus
            )
            elapsed_time = time.time() - start_time
            
            allantools_results[func_name] = {
                'tau': t_vals.tolist(),
                'dev': dev_vals.tolist(),
                'err': err_vals.tolist(),
                'n': n_vals.tolist(),
                'description': description
            }
            
            timing_results[func_name] = elapsed_time
            
            print(f"✓ {len(t_vals)} points ({elapsed_time:.2f}s)")
            
        except Exception as e:
            elapsed_time = float('nan')
            timing_results[func_name] = elapsed_time
            print(f"✗ Failed: {e}")
    
    total_elapsed = time.time() - total_start_time
    print(f"\nTotal AllanTools computation time: {total_elapsed:.2f}s")
    
    # Save results
    output_data = {
        'metadata': {
            'dataset': '6krbsnip',
            'description': 'Rubidium clock 100k point dataset',
            'N': N,
            'tau0': tau0,
            'allantools_version': allantools.__version__,
            'data_type': 'phase',
            'data_range': [float(phase_data.min()), float(phase_data.max())],
            'm_values': m_values,
            'tau_values': taus.tolist(),
            'computation_time': {
                'total_seconds': total_elapsed,
                'function_times': timing_results
            }
        },
        'results': allantools_results
    }
    
    output_file = "allantools_6krbsnip_octave.json"
    with open(output_file, 'w') as f:
        json.dump(output_data, f, indent=2)
    
    print(f"\nSaved AllanTools reference: {output_file}")
    print(f"Functions computed: {list(allantools_results.keys())}")
    
    # Print timing summary
    print(f"\n{'='*60}")
    print("AllanTools Timing Summary")
    print(f"{'='*60}")
    print(f"{'Function':<10} | {'Time (s)':<10} | {'Points':<8} | {'Rate (pts/s)':<12}")
    print("-" * 60)
    
    for func_name in allantools_results.keys():
        elapsed = timing_results[func_name]
        n_points = len(allantools_results[func_name]['tau'])
        rate_pts = n_points / elapsed if elapsed > 0 else float('inf')
        print(f"{func_name.upper():<10} | {elapsed:<10.2f} | {n_points:<8} | {rate_pts:<12.1f}")
    
    print("-" * 60)
    total_points = sum(len(result['tau']) for result in allantools_results.values())
    avg_rate = total_points / total_elapsed
    print(f"{'TOTAL':<10} | {total_elapsed:<10.2f} | {total_points:<8} | {avg_rate:<12.1f}")
    
    # Create AllanTools plots
    print(f"\n{'='*60}")
    print("Generating AllanTools plots...")
    print(f"{'='*60}")
    
    fig, axes = plt.subplots(2, 4, figsize=(16, 10))
    fig.suptitle('AllanTools Reference: 6krbsnip.txt (Rubidium Clock, 100k points)', fontsize=16)
    axes = axes.flatten()
    
    colors = ['blue', 'red', 'green', 'orange', 'purple', 'brown', 'pink']
    
    for i, (func_name, result) in enumerate(allantools_results.items()):
        if i >= len(axes):
            break
            
        ax = axes[i]
        tau_vals = np.array(result['tau'])
        dev_vals = np.array(result['dev'])
        
        ax.loglog(tau_vals, dev_vals, 'o-', color=colors[i % len(colors)], 
                 linewidth=2, markersize=4, label='AllanTools')
        ax.set_xlabel('τ (s)')
        ax.set_ylabel('Deviation')
        ax.set_title(f"{func_name.upper()}\n{result['description']}")
        ax.grid(True, alpha=0.3)
        ax.legend()
        
        # Add timing annotation
        elapsed = timing_results[func_name]
        ax.text(0.02, 0.98, f"{elapsed:.2f}s", transform=ax.transAxes, 
               verticalalignment='top', fontsize=10, 
               bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))
    
    # Hide unused subplots
    for i in range(len(allantools_results), len(axes)):
        axes[i].set_visible(False)
    
    plt.tight_layout()
    plot_file = "allantools_6krbsnip_reference.png"
    plt.savefig(plot_file, dpi=150, bbox_inches='tight')
    print(f"Saved AllanTools plot: {plot_file}")
    
    print(f"\n{'='*60}")
    print("AllanTools reference generation complete!")
    print(f"Dataset: 6krbsnip.txt ({N:,} points)")
    print(f"Total computation time: {total_elapsed:.2f}s")
    print(f"Ready for comparison with StabLab.jl")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()