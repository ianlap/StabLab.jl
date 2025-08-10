% Comprehensive 3-way benchmark: AllanLab (MATLAB)
% 20 datasets × 1M samples with OADEV, MDEV, OHDEV

function results = run_matlab_benchmark()
    fprintf('🚀 COMPREHENSIVE BENCHMARK: AllanLab (MATLAB)\n');
    fprintf('%s\n', repmat('=', 1, 60));
    fprintf('Functions: OADEV, MDEV, OHDEV\n');
    fprintf('Data: 20 datasets × 1M samples = 20M total samples\n\n');
    
    % Parameters
    N = 1000000;  % 1M samples per dataset
    num_datasets = 20;
    tau0 = 1.0;
    
    fprintf('📊 Dataset info:\n');
    fprintf('  - Sample count: %dk per dataset\n', N/1000);
    fprintf('  - Number of datasets: %d\n', num_datasets);
    fprintf('  - Total samples: %dM\n', N * num_datasets / 1000000);
    fprintf('  - Memory per dataset: ~%.1f MB\n', N * 8 / 1024^2);
    fprintf('  - Total memory: ~%.2f GB\n', N * num_datasets * 8 / 1024^3);
    fprintf('\n');
    
    % Generate datasets (White FM noise)
    rng(42);  % Set seed for reproducibility
    datasets = cell(num_datasets, 1);
    for i = 1:num_datasets
        rng(42 + i);  % Different seed for each dataset
        phase_data = cumsum(randn(N, 1)) * 1e-9;
        datasets{i} = phase_data;
    end
    
    fprintf('Generated %d datasets of White FM noise\n', num_datasets);
    fprintf('Phase noise level: ~%.1f ns RMS\n', std(datasets{1}) * 1e9);
    fprintf('\n');
    
    % Test functions: {function_handle, name, function_key}
    functions = {
        @(x, tau0) allanlab.adev(x, tau0), 'OADEV', 'oadev';
        @(x, tau0) allanlab.mdev(x, tau0), 'MDEV', 'mdev';
        @(x, tau0) allanlab.hdev(x, tau0), 'OHDEV', 'ohdev'
    };
    
    results = struct();
    
    for f = 1:size(functions, 1)
        func = functions{f, 1};
        name = functions{f, 2};
        func_key = functions{f, 3};
        
        fprintf('=== Benchmarking %s ===\n', name);
        
        times = [];
        first_values = [];
        
        for i = 1:length(datasets)
            fprintf('  Dataset %d/%d: ', i, num_datasets);
            
            phase_data = datasets{i};
            start_time = tic;
            
            try
                [tau_out, dev_out, ~, ~, ~] = func(phase_data, tau0);
                elapsed = toc(start_time);
                
                times(end+1) = elapsed;
                first_values(end+1) = dev_out(1);
                
                fprintf('%.2fs (dev[0]=%.3e)\n', elapsed, dev_out(1));
                
            catch ME
                fprintf('FAILED: %s\n', ME.message);
                return;
            end
        end
        
        % Statistics
        mean_time = mean(times);
        std_time = std(times);
        mean_first_val = mean(first_values);
        std_first_val = std(first_values);
        total_time = sum(times);
        throughput = (N * num_datasets) / total_time / 1e6;
        
        fprintf('  Results:\n');
        fprintf('    Mean time: %.3f ± %.3fs\n', mean_time, std_time);
        fprintf('    Total time: %.2fs\n', total_time);
        fprintf('    First value: %.6e ± %.2e\n', mean_first_val, std_first_val);
        fprintf('    Tau points: %d\n', length(tau_out));
        fprintf('    Throughput: %.2f Msamples/sec\n', throughput);
        fprintf('\n');
        
        results.(func_key) = struct(...
            'times', times, ...
            'mean_time', mean_time, ...
            'std_time', std_time, ...
            'total_time', total_time, ...
            'first_values', first_values, ...
            'mean_first_val', mean_first_val, ...
            'std_first_val', std_first_val, ...
            'tau_points', length(tau_out), ...
            'throughput', throughput ...
        );
    end
    
    % Overall summary
    grand_total_time = results.oadev.total_time + results.mdev.total_time + results.ohdev.total_time;
    overall_throughput = (N * num_datasets * 3) / grand_total_time / 1e6;
    
    fprintf('🏁 MATLAB ALLANLAB SUMMARY\n');
    fprintf('%s\n', repmat('=', 1, 60));
    fprintf('Total execution time: %.1fs (%.1f min)\n', grand_total_time, grand_total_time/60);
    fprintf('\n');
    fprintf('Function | Mean Time | Total Time | Tau Points | Throughput\n');
    fprintf('---------|-----------|------------|------------|-----------\n');
    
    func_keys = {'oadev', 'mdev', 'ohdev'};
    for f = 1:length(func_keys)
        func_key = func_keys{f};
        result = results.(func_key);
        fprintf('%-8s | %9.3f | %10.1f | %10d | %7.1f Msmp/s\n', ...
            upper(func_key), result.mean_time, result.total_time, ...
            result.tau_points, result.throughput);
    end
    
    fprintf('---------|-----------|------------|------------|-----------\n');
    fprintf('%-8s | %9s | %10.1f | %10s | %7.1f Msmp/s\n', ...
        'OVERALL', '-', grand_total_time, '-', overall_throughput);
    
    % Save results
    save('/tmp/matlab_comprehensive_results.mat', 'results');
    fprintf('\n💾 Results saved to /tmp/matlab_comprehensive_results.mat\n');
end

% Run if called directly
if strcmp(mfilename, 'comprehensive_benchmark')
    run_matlab_benchmark();
end