# Comprehensive 3-way benchmark: Python AllanTools
# 20 datasets × 1M samples with OADEV, MDEV, OHDEV

import numpy as np
import time
import allantools

def main():
    print("🚀 COMPREHENSIVE BENCHMARK: AllanTools (Python)")
    print("=" * 60)
    print("Functions: OADEV, MDEV, OHDEV")
    print("Data: 20 datasets × 1M samples = 20M total samples")
    print()
    
    # Parameters
    N = 1_000_000  # 1M samples per dataset
    num_datasets = 20
    tau0 = 1.0
    
    print(f"📊 Dataset info:")
    print(f"  - Sample count: {N//1000}k per dataset")
    print(f"  - Number of datasets: {num_datasets}")
    print(f"  - Total samples: {N * num_datasets // 1_000_000}M")
    print(f"  - Memory per dataset: ~{N * 8 / 1024**2:.1f} MB")
    print(f"  - Total memory: ~{N * num_datasets * 8 / 1024**3:.2f} GB")
    print()
    
    # Generate datasets (White FM noise)
    np.random.seed(42)
    datasets = []
    for i in range(num_datasets):
        np.random.seed(42 + i)  # Different seed for each dataset
        phase_data = np.cumsum(np.random.randn(N)) * 1e-9
        datasets.append(phase_data)
    
    print(f"Generated {num_datasets} datasets of White FM noise")
    print(f"Phase noise level: ~{np.std(datasets[0]) * 1e9:.1f} ns RMS")
    print()
    
    # Test functions: (function, name, allantools_name)
    functions = [
        (allantools.oadev, "OADEV", "oadev"),
        (allantools.mdev, "MDEV", "mdev"),
        (allantools.ohdev, "OHDEV", "ohdev")
    ]
    
    results = {}
    
    for func, name, func_key in functions:
        print(f"=== Benchmarking {name} ===")
        
        times = []
        first_values = []
        
        for i, phase_data in enumerate(datasets):
            print(f"  Dataset {i+1}/{num_datasets}: ", end="", flush=True)
            
            start_time = time.time()
            try:
                (tau_out, dev_out, deverr_out, n_out) = func(phase_data, rate=1/tau0, data_type="phase")
                elapsed = time.time() - start_time
                
                times.append(elapsed)
                first_values.append(dev_out[0])
                
                print(f"{elapsed:.2f}s (dev[0]={dev_out[0]:.3e})")
                
            except Exception as e:
                print(f"FAILED: {e}")
                return None
        
        # Statistics
        mean_time = np.mean(times)
        std_time = np.std(times)
        mean_first_val = np.mean(first_values)
        std_first_val = np.std(first_values)
        total_time = np.sum(times)
        throughput = (N * num_datasets) / total_time / 1e6
        
        print("  Results:")
        print(f"    Mean time: {mean_time:.3f} ± {std_time:.3f}s")
        print(f"    Total time: {total_time:.2f}s")
        print(f"    First value: {mean_first_val:.6e} ± {std_first_val:.2e}")
        print(f"    Tau points: {len(tau_out)}")
        print(f"    Throughput: {throughput:.2f} Msamples/sec")
        print()
        
        results[func_key] = {
            "times": times,
            "mean_time": mean_time,
            "std_time": std_time,
            "total_time": total_time,
            "first_values": first_values,
            "mean_first_val": mean_first_val,
            "std_first_val": std_first_val,
            "tau_points": len(tau_out),
            "throughput": throughput
        }
    
    # Overall summary
    grand_total_time = sum([results[f]["total_time"] for f in ["oadev", "mdev", "ohdev"]])
    overall_throughput = (N * num_datasets * 3) / grand_total_time / 1e6
    
    print("🏁 PYTHON ALLANTOOLS SUMMARY")
    print("=" * 60)
    print(f"Total execution time: {grand_total_time:.1f}s ({grand_total_time/60:.1f} min)")
    print()
    print("Function | Mean Time | Total Time | Tau Points | Throughput")
    print("---------|-----------|------------|------------|------------")
    
    for func_key in ["oadev", "mdev", "ohdev"]:
        result = results[func_key]
        print(f"{func_key.upper():8} | {result['mean_time']:9.3f} | {result['total_time']:10.1f} | {result['tau_points']:10d} | {result['throughput']:7.1f} Msmp/s")
    
    print("---------|-----------|------------|------------|------------")
    print(f"{'OVERALL':8} | {'-':9} | {grand_total_time:10.1f} | {'-':10} | {overall_throughput:7.1f} Msmp/s")
    
    # Save results
    np.savez("/tmp/python_comprehensive_results.npz", **results)
    print(f"\n💾 Results saved to /tmp/python_comprehensive_results.npz")
    
    return results

if __name__ == "__main__":
    main()