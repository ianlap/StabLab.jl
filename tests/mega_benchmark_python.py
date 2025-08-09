#!/usr/bin/env python3
"""
Mega Benchmark: AllanTools (Python) vs StabLab.jl vs MATLAB
Tests ADEV, MDEV, HDEV with 10^7 data points across 30 datasets
"""

import numpy as np
import time
import sys
import os
from statistics import mean, stdev
import matplotlib.pyplot as plt

# Add allantools to path
sys.path.insert(0, '/Users/ianlapinski/Desktop/masterclock-kflab/allantools')

try:
    import allantools as at
except ImportError:
    print("Error: allantools not found. Please check the path.")
    sys.exit(1)

def generate_test_datasets(N=10_000_000, num_datasets=30, tau0=1.0):
    """Generate multiple test datasets for benchmarking"""
    print(f"Generating {num_datasets} datasets of {N:,} samples each...")
    
    datasets = []
    reference_results = []
    
    for i in range(num_datasets):
        # Use different seeds for each dataset
        np.random.seed(42 + i)
        phase_data = np.cumsum(np.random.randn(N)) * 1e-9
        datasets.append(phase_data)
        
        if i == 0:
            # Save first dataset for validation
            np.save('/tmp/mega_benchmark_data.npy', phase_data)
            print(f"  Dataset 0 saved for cross-validation")
            print(f"  Range: [{phase_data.min():.2e}, {phase_data.max():.2e}]")
    
    return datasets, tau0

def benchmark_function(func, datasets, tau0, func_name, max_tau_points=20):
    """Benchmark a single function across all datasets"""
    print(f"\n=== Benchmarking {func_name.upper()} ===")
    
    N = len(datasets[0])
    # Generate m_list (octave-spaced)
    max_m = N // 4
    m_list = []
    m = 1
    while m <= max_m and len(m_list) < max_tau_points:
        m_list.append(m)
        m *= 2
    
    times = []
    first_values = []
    all_results = []
    
    for i, phase_data in enumerate(datasets):
        print(f"  Dataset {i+1}/{len(datasets)}: ", end='', flush=True)
        
        start_time = time.time()
        try:
            if func_name == 'adev':
                (taus, devs, errs, ns) = at.oadev(phase_data, rate=1/tau0, data_type='phase', taus=m_list)
            elif func_name == 'mdev':
                (taus, devs, errs, ns) = at.mdev(phase_data, rate=1/tau0, data_type='phase', taus=m_list)
            elif func_name == 'hdev':
                (taus, devs, errs, ns) = at.ohdev(phase_data, rate=1/tau0, data_type='phase', taus=m_list)
            else:
                raise ValueError(f"Unknown function: {func_name}")
                
            elapsed = time.time() - start_time
            times.append(elapsed)
            first_values.append(devs[0])
            
            if i == 0:  # Save first result for validation
                all_results = {'tau': taus, 'dev': devs}
            
            print(f"{elapsed:.2f}s (dev[0]={devs[0]:.3e})")
            
        except Exception as e:
            print(f"FAILED: {e}")
            return None
    
    # Statistics
    mean_time = mean(times)
    std_time = stdev(times) if len(times) > 1 else 0.0
    mean_first_val = mean(first_values)
    std_first_val = stdev(first_values) if len(first_values) > 1 else 0.0
    
    print(f"  Results:")
    print(f"    Mean time: {mean_time:.3f} ± {std_time:.3f}s")
    print(f"    Total time: {sum(times):.2f}s")
    print(f"    First value: {mean_first_val:.6e} ± {std_first_val:.2e}")
    print(f"    Throughput: {N * len(datasets) / sum(times) / 1e6:.2f} Msamples/sec")
    
    return {
        'times': times,
        'mean_time': mean_time,
        'std_time': std_time,
        'total_time': sum(times),
        'first_values': first_values,
        'mean_first_val': mean_first_val,
        'std_first_val': std_first_val,
        'results': all_results,
        'tau_points': len(all_results['tau']) if all_results else 0
    }

def save_output_and_plots(results, total_time, N, num_datasets):
    """Save output to text file and create performance plots"""
    
    # Save text output
    with open('/tmp/python_mega_benchmark_results.txt', 'w') as f:
        f.write("🚀 MEGA BENCHMARK: AllanTools (Python)\n")
        f.write("=" * 60 + "\n")
        f.write(f"Target: 30 datasets × 10^7 samples = 3 × 10^8 total samples\n")
        f.write(f"Functions: ADEV, MDEV, HDEV\n\n")
        
        f.write(f"📊 Dataset info:\n")
        f.write(f"  - Sample count: {N:,} per dataset\n")
        f.write(f"  - Number of datasets: {num_datasets}\n")
        f.write(f"  - Total samples: {N * num_datasets:,}\n")
        f.write(f"  - Memory per dataset: ~{N * 8 / 1024**2:.1f} MB\n")
        f.write(f"  - Total memory: ~{N * num_datasets * 8 / 1024**3:.2f} GB\n\n")
        
        f.write(f"🏁 PYTHON ALLANTOOLS SUMMARY\n")
        f.write("=" * 60 + "\n")
        f.write(f"Total execution time: {total_time:.2f}s ({total_time/60:.1f} min)\n\n")
        
        grand_total_time = 0
        functions = ['adev', 'mdev', 'hdev']
        for func_name in functions:
            result = results[func_name]
            grand_total_time += result['total_time']
            f.write(f"{func_name.upper():4s}: {result['mean_time']:6.2f} ± {result['std_time']:5.2f}s per dataset, "
                   f"{result['total_time']:7.1f}s total, {result['tau_points']:2d} tau points\n")
        
        overall_throughput = (N * num_datasets * len(functions)) / grand_total_time / 1e6
        f.write(f"Overall throughput: {overall_throughput:.2f} Msamples/sec\n")
    
    print(f"💾 Text results saved to /tmp/python_mega_benchmark_results.txt")
    
    # Create performance plots
    functions = ['adev', 'mdev', 'hdev']
    
    # Plot 1: Timing distribution across datasets
    plt.figure(figsize=(15, 5))
    
    plt.subplot(1, 3, 1)
    for i, func_name in enumerate(functions):
        times = results[func_name]['times']
        plt.hist(times, alpha=0.7, label=func_name.upper(), bins=10)
    plt.xlabel('Time per dataset (s)')
    plt.ylabel('Count')
    plt.title('Timing Distribution Across 30 Datasets')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Plot 2: Mean performance comparison
    plt.subplot(1, 3, 2)
    mean_times = [results[func]['mean_time'] for func in functions]
    std_times = [results[func]['std_time'] for func in functions]
    
    bars = plt.bar(functions, mean_times, yerr=std_times, capsize=5, 
                   color=['#1f77b4', '#ff7f0e', '#2ca02c'], alpha=0.8)
    plt.ylabel('Mean time per dataset (s)')
    plt.title('Mean Performance ± Std Dev')
    plt.grid(True, alpha=0.3)
    
    # Add value labels on bars
    for bar, mean_time in zip(bars, mean_times):
        plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.1,
                f'{mean_time:.2f}s', ha='center', va='bottom')
    
    # Plot 3: First value consistency
    plt.subplot(1, 3, 3)
    for func_name in functions:
        first_vals = results[func_name]['first_values']
        plt.hist(first_vals, alpha=0.7, label=func_name.upper(), bins=15)
    plt.xlabel('First deviation value')
    plt.ylabel('Count')
    plt.title('First Value Distribution (Consistency Check)')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.ticklabel_format(style='scientific', axis='x', scilimits=(0,0))
    
    plt.tight_layout()
    plt.savefig('/tmp/python_mega_benchmark_plots.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"📊 Performance plots saved to /tmp/python_mega_benchmark_plots.png")

def main():
    # Redirect output to both console and file
    import sys
    from contextlib import redirect_stdout
    
    class TeeOutput:
        def __init__(self, *files):
            self.files = files
        def write(self, text):
            for file in self.files:
                file.write(text)
                file.flush()
        def flush(self):
            for file in self.files:
                file.flush()
    
    with open('/tmp/python_mega_benchmark_log.txt', 'w') as log_file:
        tee = TeeOutput(sys.stdout, log_file)
        with redirect_stdout(tee):
            print("🚀 MEGA BENCHMARK: AllanTools (Python)")
            print("=" * 60)
            print(f"Target: 30 datasets × 10^7 samples = 3 × 10^8 total samples")
            print(f"Functions: ADEV, MDEV, HDEV")
            print()
    
    # Generate datasets
    N = 10_000_000
    num_datasets = 30
    datasets, tau0 = generate_test_datasets(N, num_datasets, tau0=1.0)
    
    print(f"\n📊 Dataset info:")
    print(f"  - Sample count: {N:,} per dataset")
    print(f"  - Number of datasets: {num_datasets}")
    print(f"  - Total samples: {N * num_datasets:,}")
    print(f"  - Memory per dataset: ~{N * 8 / 1024**2:.1f} MB")
    print(f"  - Total memory: ~{N * num_datasets * 8 / 1024**3:.2f} GB")
    
    # Benchmark functions
    functions = ['adev', 'mdev', 'hdev']
    results = {}
    
    total_start_time = time.time()
    
    for func_name in functions:
        results[func_name] = benchmark_function(None, datasets, tau0, func_name)
        if results[func_name] is None:
            print(f"❌ {func_name.upper()} failed!")
            return
    
    total_time = time.time() - total_start_time
    
    # Summary
    print(f"\n🏁 PYTHON ALLANTOOLS SUMMARY")
    print("=" * 60)
    print(f"Total execution time: {total_time:.2f}s ({total_time/60:.1f} min)")
    
    grand_total_time = 0
    for func_name in functions:
        result = results[func_name]
        grand_total_time += result['total_time']
        print(f"{func_name.upper():4s}: {result['mean_time']:6.2f} ± {result['std_time']:5.2f}s per dataset, "
              f"{result['total_time']:7.1f}s total, {result['tau_points']:2d} tau points")
    
    overall_throughput = (N * num_datasets * len(functions)) / grand_total_time / 1e6
    print(f"Overall throughput: {overall_throughput:.2f} Msamples/sec")
    
    # Save results for comparison
    save_data = {}
    for func_name in functions:
        result = results[func_name]
        save_data[f'{func_name}_mean_time'] = result['mean_time']
        save_data[f'{func_name}_std_time'] = result['std_time']
        save_data[f'{func_name}_total_time'] = result['total_time']
        save_data[f'{func_name}_mean_first_val'] = result['mean_first_val']
        save_data[f'{func_name}_std_first_val'] = result['std_first_val']
        save_data[f'{func_name}_tau'] = result['results']['tau']
        save_data[f'{func_name}_dev'] = result['results']['dev']
    
    save_data['total_time'] = grand_total_time
    save_data['N'] = N
    save_data['num_datasets'] = num_datasets
    save_data['tau0'] = tau0
    
    np.savez('/tmp/python_mega_results.npz', **save_data)
    
    # Save output and create plots
    save_output_and_plots(results, total_time, N, num_datasets)
    
    print(f"\n💾 Results saved to /tmp/python_mega_results.npz")
    print(f"💾 Reference dataset saved to /tmp/mega_benchmark_data.npy")
    print(f"\n🎯 Ready for Julia and MATLAB comparisons!")

if __name__ == "__main__":
    main()