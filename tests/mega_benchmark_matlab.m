function mega_benchmark_matlab()
%MEGA_BENCHMARK_MATLAB Comprehensive MATLAB AllanLab benchmark
% Tests ADEV, MDEV, HDEV with 10^7 data points across 30 datasets

fprintf('MEGA BENCHMARK: MATLAB AllanLab\n');
fprintf('=====================================\n');
fprintf('Target: 30 datasets x 10^7 samples = 3 x 10^8 total samples\n');
fprintf('Functions: ADEV, MDEV, HDEV\n\n');

% Add AllanLab to path
addpath('/Users/ianlapinski/Desktop/masterclock-kflab/matlab/AllanLab');

% Configuration
N = 10000000;  % 10M samples per dataset
num_datasets = 30;
tau0 = 1.0;

% Check if reference data exists from Python
reference_data_file = '/tmp/mega_benchmark_data.npy';
if exist(reference_data_file, 'file')
    fprintf('Loading reference dataset from Python benchmark...\n');
    try
        reference_data = readNPY(reference_data_file);
        fprintf('Reference data loaded: %d samples\n', length(reference_data));
        fprintf('Range: [%.2e, %.2e]\n', min(reference_data), max(reference_data));
    catch ME
        fprintf('Error loading reference data: %s\n', ME.message);
        reference_data = [];
    end
else
    fprintf('No reference data found, will generate new datasets\n');
    reference_data = [];
end

fprintf('\nDataset info:\n');
fprintf('  - Sample count: %dM per dataset\n', N/1000000);
fprintf('  - Number of datasets: %d\n', num_datasets);
fprintf('  - Total samples: %dM\n', (N * num_datasets)/1000000);
fprintf('  - Memory per dataset: ~%.1f MB\n', N * 8 / 1024^2);
fprintf('  - Total memory: ~%.2f GB\n', N * num_datasets * 8 / 1024^3);

% Generate datasets
fprintf('\nGenerating %d datasets of %dM samples each...\n', num_datasets, N/1000000);
datasets = cell(num_datasets, 1);

for i = 1:num_datasets
    % Use same seeds as Python/Julia (MATLAB rng is different but consistent)
    rng(42 + i - 1, 'twister');
    phase_data = cumsum(randn(N, 1)) * 1e-9;
    datasets{i} = phase_data;
    
    if i == 1
        fprintf('  Dataset 1: range [%.2e, %.2e]\n', min(phase_data), max(phase_data));
    end
end

% Generate m_list (octave-spaced) - matching Python/Julia
max_tau_points = 20;
max_m = floor(N / 4);
m_list = [];
m = 1;
while m <= max_m && length(m_list) < max_tau_points
    m_list = [m_list, m];
    m = m * 2;
end

% Benchmark functions
functions = {'adev', 'mdev', 'hdev'};
results = struct();

total_start_time = tic;

for func_idx = 1:length(functions)
    func_name = functions{func_idx};
    fprintf('\n=== Benchmarking %s ===\n', upper(func_name));
    
    times = [];
    first_values = [];
    all_results = struct();
    
    for dataset_idx = 1:num_datasets
        fprintf('  Dataset %d/%d: ', dataset_idx, num_datasets);
        phase_data = datasets{dataset_idx};
        
        start_time = tic;
        try
            if strcmp(func_name, 'adev')
                [tau_vals, dev_vals, edf_vals, ci_vals, alpha_vals] = allanlab.adev(phase_data, tau0, m_list);
            elseif strcmp(func_name, 'mdev')
                [tau_vals, dev_vals, edf_vals, ci_vals, alpha_vals] = allanlab.mdev(phase_data, tau0, m_list);
            elseif strcmp(func_name, 'hdev')
                [tau_vals, dev_vals, edf_vals, ci_vals, alpha_vals] = allanlab.hdev(phase_data, tau0, m_list);
            end
            
            elapsed = toc(start_time);
            times = [times, elapsed];
            first_values = [first_values, dev_vals(1)];
            
            if dataset_idx == 1
                all_results.tau = tau_vals;
                all_results.dev = dev_vals;
            end
            
            fprintf('%.2fs (dev[0]=%.3e)\n', elapsed, dev_vals(1));
            
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
    
    fprintf('  Results:\n');
    fprintf('    Mean time: %.3f ± %.3f s\n', mean_time, std_time);
    fprintf('    Total time: %.2f s\n', total_time);
    fprintf('    First value: %.6e ± %.2e\n', mean_first_val, std_first_val);
    fprintf('    Throughput: %.2f Msamples/sec\n', N * num_datasets / total_time / 1e6);
    
    % Store results
    results.(func_name).times = times;
    results.(func_name).mean_time = mean_time;
    results.(func_name).std_time = std_time;
    results.(func_name).total_time = total_time;
    results.(func_name).first_values = first_values;
    results.(func_name).mean_first_val = mean_first_val;
    results.(func_name).std_first_val = std_first_val;
    results.(func_name).results = all_results;
    results.(func_name).tau_points = length(all_results.tau);
end

total_time = toc(total_start_time);

% Summary
fprintf('\nMATLAB ALLANLAB SUMMARY\n');
fprintf('=====================================\n');
fprintf('Total execution time: %.2f s (%.1f min)\n', total_time, total_time/60);

grand_total_time = 0;
for func_idx = 1:length(functions)
    func_name = functions{func_idx};
    result = results.(func_name);
    grand_total_time = grand_total_time + result.total_time;
    fprintf('%s: %6.2f ± %5.2f s per dataset, %7.1f s total, %2d tau points\n', ...
        upper(func_name), result.mean_time, result.std_time, result.total_time, result.tau_points);
end

overall_throughput = (N * num_datasets * length(functions)) / grand_total_time / 1e6;
fprintf('Overall throughput: %.2f Msamples/sec\n', overall_throughput);

% Save results
save_results_and_plots(results, total_time, N, num_datasets);

% Save results for comparison
results.total_time = grand_total_time;
results.N = N;
results.num_datasets = num_datasets;
results.tau0 = tau0;

save('/tmp/matlab_mega_results.mat', 'results');

fprintf('\nResults saved to /tmp/matlab_mega_results.mat\n');
fprintf('Ready for three-way comparison!\n');

end

function save_results_and_plots(results, total_time, N, num_datasets)
%SAVE_RESULTS_AND_PLOTS Save text output and create plots

% Save text output
fid = fopen('/tmp/matlab_mega_benchmark_results.txt', 'w');
fprintf(fid, 'MEGA BENCHMARK: MATLAB AllanLab\n');
fprintf(fid, '=====================================\n');
fprintf(fid, 'Target: 30 datasets x 10^7 samples = 3 x 10^8 total samples\n');
fprintf(fid, 'Functions: ADEV, MDEV, HDEV\n\n');

fprintf(fid, 'Dataset info:\n');
fprintf(fid, '  - Sample count: %dM per dataset\n', N/1000000);
fprintf(fid, '  - Number of datasets: %d\n', num_datasets);
fprintf(fid, '  - Total samples: %dM\n', (N * num_datasets)/1000000);
fprintf(fid, '  - Memory per dataset: ~%.1f MB\n', N * 8 / 1024^2);
fprintf(fid, '  - Total memory: ~%.2f GB\n', N * num_datasets * 8 / 1024^3);

fprintf(fid, '\nMATLAB ALLANLAB SUMMARY\n');
fprintf(fid, '=====================================\n');
fprintf(fid, 'Total execution time: %.2f s (%.1f min)\n', total_time, total_time/60);

functions = {'adev', 'mdev', 'hdev'};
grand_total_time = 0;
for func_idx = 1:length(functions)
    func_name = functions{func_idx};
    result = results.(func_name);
    grand_total_time = grand_total_time + result.total_time;
    fprintf(fid, '%s: %6.2f ± %5.2f s per dataset, %7.1f s total, %2d tau points\n', ...
        upper(func_name), result.mean_time, result.std_time, result.total_time, result.tau_points);
end

overall_throughput = (N * num_datasets * length(functions)) / grand_total_time / 1e6;
fprintf(fid, 'Overall throughput: %.2f Msamples/sec\n', overall_throughput);
fclose(fid);

fprintf('Text results saved to /tmp/matlab_mega_benchmark_results.txt\n');

% Create performance plots
try
    figure('Visible', 'off', 'Position', [100, 100, 1500, 400]);
    
    % Plot 1: Timing distribution
    subplot(1, 3, 1);
    hold on;
    colors = {'b', 'r', 'g'};
    for func_idx = 1:length(functions)
        func_name = functions{func_idx};
        times = results.(func_name).times;
        histogram(times, 10, 'FaceAlpha', 0.7, 'DisplayName', upper(func_name), 'FaceColor', colors{func_idx});
    end
    xlabel('Time per dataset (s)');
    ylabel('Count');
    title('Timing Distribution Across 30 Datasets');
    legend('show');
    grid on;
    
    % Plot 2: Mean performance comparison
    subplot(1, 3, 2);
    mean_times = [];
    std_times = [];
    for func_idx = 1:length(functions)
        func_name = functions{func_idx};
        mean_times = [mean_times, results.(func_name).mean_time];
        std_times = [std_times, results.(func_name).std_time];
    end
    
    bar_handle = bar(mean_times);
    hold on;
    errorbar(1:length(functions), mean_times, std_times, 'k.', 'LineWidth', 2);
    set(gca, 'XTickLabel', upper(functions));
    ylabel('Mean time per dataset (s)');
    title('Mean Performance ± Std Dev');
    grid on;
    
    % Plot 3: First value consistency
    subplot(1, 3, 3);
    hold on;
    for func_idx = 1:length(functions)
        func_name = functions{func_idx};
        first_vals = results.(func_name).first_values;
        histogram(first_vals, 15, 'FaceAlpha', 0.7, 'DisplayName', upper(func_name), 'FaceColor', colors{func_idx});
    end
    xlabel('First deviation value');
    ylabel('Count');
    title('First Value Distribution (Consistency Check)');
    legend('show');
    grid on;
    
    % Save plot
    print('/tmp/matlab_mega_benchmark_plots.png', '-dpng', '-r300');
    close;
    
    fprintf('Performance plots saved to /tmp/matlab_mega_benchmark_plots.png\n');
catch ME
    fprintf('Warning: Could not create plots: %s\n', ME.message);
end

end

% Helper function to read NPY files
function data = readNPY(filename)
    % Simple NPY reader for our use case
    fid = fopen(filename, 'r', 'ieee-le');
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    
    % Skip NPY header (simplified - assumes our specific format)
    magic = fread(fid, 6, 'uint8');
    version = fread(fid, 2, 'uint8');
    header_len = fread(fid, 2, 'uint16');
    header = fread(fid, header_len, 'char');
    
    % Read data as double precision
    data = fread(fid, inf, 'double');
    fclose(fid);
end