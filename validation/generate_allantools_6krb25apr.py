#!/usr/bin/env python3
"""
Generate AllanTools reference data for 6krb25apr.txt with full octave spacing
"""

import numpy as np
import allantools
import json
import matplotlib.pyplot as plt
from pathlib import Path

def main():
    print("Generating AllanTools reference for 6krb25apr.txt with octave spacing")
    print("="*60)
    
    # Load data
    data_file = Path("data/6krb25apr.txt")
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
    
    # Compute all available functions
    allantools_results = {}
    
    functions_to_test = [
        ('adev', allantools.oadev, "Allan Deviation (Overlapping)"),
        ('mdev', allantools.mdev, "Modified Allan Deviation"),
        ('tdev', allantools.tdev, "Time Deviation"), 
        ('hdev', allantools.ohdev, "Hadamard Deviation (Overlapping)"),
        ('totdev', allantools.totdev, "Total Deviation"),
        ('mtotdev', allantools.mtotdev, "Modified Total Deviation"),
        ('pdev', allantools.pdev, "Parabolic Deviation")
    ]
    
    for func_name, func, description in functions_to_test:
        try:
            print(f"Computing {func_name} ({description})...")
            
            (t_vals, dev_vals, err_vals, n_vals) = func(
                phase_data, rate=rate, data_type="phase", taus=taus
            )
            
            allantools_results[func_name] = {
                'tau': t_vals.tolist(),
                'dev': dev_vals.tolist(),
                'err': err_vals.tolist(),
                'n': n_vals.tolist(),
                'description': description
            }
            
            print(f"  ✓ {func_name}: {len(t_vals)} points")
            
        except Exception as e:
            print(f"  ✗ {func_name} failed: {e}")
    
    # Save results
    output_data = {
        'metadata': {
            'dataset': '6krb25apr',
            'description': 'Rubidium clock full dataset',
            'N': N,
            'tau0': tau0,
            'allantools_version': allantools.__version__,
            'data_type': 'phase',
            'data_range': [float(phase_data.min()), float(phase_data.max())],
            'm_values': m_values,
            'tau_values': taus.tolist()
        },
        'results': allantools_results
    }
    
    output_file = "allantools_6krb25apr_octave.json"
    with open(output_file, 'w') as f:
        json.dump(output_data, f, indent=2)
    
    print(f"\nSaved AllanTools reference: {output_file}")
    print(f"Functions computed: {list(allantools_results.keys())}")
    
    # Create AllanTools plots
    print("\nGenerating AllanTools plots...")
    
    fig, axes = plt.subplots(2, 4, figsize=(16, 10))
    fig.suptitle('AllanTools Reference: 6krb25apr.txt (Rubidium Clock)', fontsize=16)
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
    
    # Hide unused subplots
    for i in range(len(allantools_results), len(axes)):
        axes[i].set_visible(False)
    
    plt.tight_layout()
    plot_file = "allantools_6krb25apr_reference.png"
    plt.savefig(plot_file, dpi=150, bbox_inches='tight')
    print(f"Saved AllanTools plot: {plot_file}")
    
    print("\nAllanTools reference generation complete!")
    print("Ready for comparison with StabLab.jl")

if __name__ == "__main__":
    main()