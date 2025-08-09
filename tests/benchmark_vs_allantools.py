#!/usr/bin/env python3
"""
Benchmark StabLab.jl against allantools (Python)
Tests: hdev (ohdev), mdev, adev (oadev) with large datasets (5e6 samples)
"""

import numpy as np
import time
import sys
import os

# Add allantools to path
sys.path.insert(0, '/Users/ianlapinski/Desktop/masterclock-kflab/allantools')

try:
    import allantools as at
except ImportError:
    print("Error: allantools not found. Please check the path.")
    sys.exit(1)

def generate_test_data(N=5000000, tau0=1.0):
    """Generate White FM noise (random walk phase) test data"""
    np.random.seed(42)  # For reproducibility
    phase_data = np.cumsum(np.random.randn(N)) * 1e-9
    return phase_data, tau0

def benchmark_allantools(phase_data, tau0, max_tau_points=20):
    """Benchmark allantools functions"""
    print("=== AllanTools (Python) Benchmark ===")
    
    # Generate m_list (octave-spaced)
    N = len(phase_data)
    max_m = N // 4  # Conservative for all functions
    m_list = []
    m = 1
    while m <= max_m and len(m_list) < max_tau_points:
        m_list.append(m)
        m *= 2
    
    results = {}
    
    # Test ADEV (oadev in allantools)
    print(f"Testing ADEV with {N} samples...")
    start_time = time.time()
    try:
        (taus_adev, adevs, adev_errs, ns_adev) = at.oadev(phase_data, rate=1/tau0, data_type='phase', taus=m_list)
        adev_time = time.time() - start_time
        results['adev'] = {
            'tau': taus_adev,
            'deviation': adevs,
            'time': adev_time,
            'points': len(taus_adev)
        }
        print(f"  ✓ ADEV: {len(taus_adev)} points in {adev_time:.3f}s")
    except Exception as e:
        print(f"  ❌ ADEV failed: {e}")
        
    # Test MDEV
    print(f"Testing MDEV with {N} samples...")
    start_time = time.time()
    try:
        (taus_mdev, mdevs, mdev_errs, ns_mdev) = at.mdev(phase_data, rate=1/tau0, data_type='phase', taus=m_list)
        mdev_time = time.time() - start_time
        results['mdev'] = {
            'tau': taus_mdev,
            'deviation': mdevs,
            'time': mdev_time,
            'points': len(taus_mdev)
        }
        print(f"  ✓ MDEV: {len(taus_mdev)} points in {mdev_time:.3f}s")
    except Exception as e:
        print(f"  ❌ MDEV failed: {e}")
        
    # Test HDEV (ohdev in allantools)
    print(f"Testing HDEV with {N} samples...")
    start_time = time.time()
    try:
        (taus_hdev, hdevs, hdev_errs, ns_hdev) = at.ohdev(phase_data, rate=1/tau0, data_type='phase', taus=m_list)
        hdev_time = time.time() - start_time
        results['hdev'] = {
            'tau': taus_hdev,
            'deviation': hdevs,
            'time': hdev_time,
            'points': len(taus_hdev)
        }
        print(f"  ✓ HDEV: {len(taus_hdev)} points in {hdev_time:.3f}s")
    except Exception as e:
        print(f"  ❌ HDEV failed: {e}")
    
    return results

def save_results(results, filename):
    """Save results to file for Julia comparison"""
    np.savez(filename, **results)
    print(f"Results saved to {filename}")

if __name__ == "__main__":
    print("StabLab.jl vs AllanTools Benchmark")
    print("=" * 50)
    
    # Generate test data
    print("Generating test data...")
    N = int(5e6)  # 5 million samples
    tau0 = 1.0
    
    phase_data, tau0 = generate_test_data(N, tau0)
    print(f"Generated {N} samples of White FM noise")
    print(f"Data range: [{phase_data.min():.2e}, {phase_data.max():.2e}]")
    print(f"Sampling interval: {tau0} seconds\n")
    
    # Run allantools benchmark
    results = benchmark_allantools(phase_data, tau0)
    
    # Save phase data for Julia
    np.save('/tmp/benchmark_phase_data.npy', phase_data)
    print(f"\nPhase data saved to /tmp/benchmark_phase_data.npy")
    
    # Save results for comparison
    allantools_results = {}
    for func_name, result in results.items():
        allantools_results[f'{func_name}_tau'] = result['tau']
        allantools_results[f'{func_name}_dev'] = result['deviation']
        allantools_results[f'{func_name}_time'] = result['time']
    
    save_results(allantools_results, '/tmp/allantools_results.npz')
    
    # Summary
    print("\n=== AllanTools Summary ===")
    total_time = sum(r['time'] for r in results.values())
    print(f"Total computation time: {total_time:.3f}s")
    for func_name, result in results.items():
        print(f"  {func_name.upper()}: {result['points']} points, {result['time']:.3f}s")
        if result['points'] > 0:
            print(f"    First value: {result['deviation'][0]:.6e}")