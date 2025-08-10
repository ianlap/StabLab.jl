function generate_matlab_reference()
%GENERATE_MATLAB_REFERENCE Generate reference data using MATLAB AllanLab for StabLab.jl validation
%
% This script creates comprehensive reference values using the official MATLAB
% AllanLab toolbox that can be compared against Julia implementations.

fprintf('Generating MATLAB AllanLab reference data...\n');

% Add AllanLab to path (adjust path as needed)
matlab_allanlab_path = '/Users/ianlapinski/Desktop/masterclock-kflab/matlab/AllanLab';
if exist(matlab_allanlab_path, 'dir')
    addpath(genpath(matlab_allanlab_path));
    fprintf('Added AllanLab path: %s\n', matlab_allanlab_path);
else
    fprintf('Warning: AllanLab path not found: %s\n', matlab_allanlab_path);
    fprintf('Please adjust the matlab_allanlab_path variable in this script.\n');
    return;
end

% Generate reproducible test data
rng(42, 'twister');  % Set seed for reproducibility
N = 10000;
tau0 = 1.0;

fprintf('\nGenerating test datasets (N=%d, tau0=%.1f)...\n', N, tau0);

% Dataset 1: White phase noise
phase_white = cumsum(randn(N, 1)) * 1e-9;

% Dataset 2: Flicker frequency noise (approximate)
freq_flicker = randn(N, 1) ./ sqrt((1:N)') * 1e-11;
phase_flicker = cumsum(cumsum(freq_flicker));

% Dataset 3: Random walk frequency  
freq_rw = cumsum(randn(N, 1)) * 1e-12;
phase_rw = cumsum(cumsum(freq_rw));

datasets = struct();
datasets.white_phase = phase_white;
datasets.flicker_freq = phase_flicker;
datasets.rw_freq = phase_rw;

dataset_names = {'white_phase', 'flicker_freq', 'rw_freq'};

% Output directory
output_dir = 'validation';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Process each dataset
for i = 1:length(dataset_names)
    dataset_name = dataset_names{i};
    phase_data = datasets.(dataset_name);
    
    fprintf('\n%s\n', repmat('=', 1, 50));
    fprintf('Processing %s dataset\n', dataset_name);
    fprintf('%s\n', repmat('=', 1, 50));
    
    % Compute MATLAB deviations
    results = compute_matlab_deviations(phase_data, tau0);
    
    % Save results as JSON
    output_file = fullfile(output_dir, sprintf('matlab_reference_%s.json', dataset_name));
    
    % Create metadata
    metadata = struct();
    metadata.dataset = dataset_name;
    metadata.N = length(phase_data);
    metadata.tau0 = tau0;
    metadata.seed = 42;
    metadata.matlab_version = version();
    metadata.data_type = 'phase';
    metadata.data_range = [min(phase_data), max(phase_data)];
    
    output_data = struct();
    output_data.metadata = metadata;
    output_data.results = results;
    
    % Write JSON file
    write_json_file(output_file, output_data);
    
    fprintf('Saved: %s\n', output_file);
    fprintf('Functions computed: %s\n', strjoin(fieldnames(results), ', '));
end

% Save test datasets for Julia to use
test_data_file = fullfile(output_dir, 'test_datasets_matlab.json');
test_data = struct();
test_data.metadata = struct('N', N, 'tau0', tau0, 'seed', 42);
test_data.datasets = datasets;

write_json_file(test_data_file, test_data);

fprintf('\nSaved test datasets: %s\n', test_data_file);
fprintf('MATLAB reference generation complete!\n');

end

function results = compute_matlab_deviations(phase_data, tau0)
%COMPUTE_MATLAB_DEVIATIONS Compute all deviations using MATLAB AllanLab

results = struct();
N = length(phase_data);

% Standard tau list (octave-spaced like AllanLab default)
max_m = floor(N/10);  % Conservative limit
m_values = unique(round(logspace(0, log10(max_m), 20)));
tau_values = m_values * tau0;

fprintf('Computing MATLAB deviations for N=%d points...\n', N);
fprintf('Tau range: %.1f to %.1f seconds (%d points)\n', min(tau_values), max(tau_values), length(tau_values));

try
    % Allan deviation
    fprintf('  Computing ADEV...\n');
    [tau_adev, adev_vals, ~, ~] = allanvar(phase_data, tau0, m_values);
    results.adev = struct('tau', tau_adev, 'dev', sqrt(adev_vals), 'm', m_values);
    fprintf('    ADEV: %d points\n', length(tau_adev));
catch ME
    fprintf('    ADEV failed: %s\n', ME.message);
end

try
    % Modified Allan deviation
    fprintf('  Computing MDEV...\n');
    [tau_mdev, mdev_vals, ~, ~] = modvar(phase_data, tau0, m_values);
    results.mdev = struct('tau', tau_mdev, 'dev', sqrt(mdev_vals), 'm', m_values);
    fprintf('    MDEV: %d points\n', length(tau_mdev));
catch ME
    fprintf('    MDEV failed: %s\n', ME.message);
end

try
    % Time deviation  
    fprintf('  Computing TDEV...\n');
    [tau_tdev, tdev_vals, ~, ~] = timevar(phase_data, tau0, m_values);
    results.tdev = struct('tau', tau_tdev, 'dev', sqrt(tdev_vals), 'm', m_values);
    fprintf('    TDEV: %d points\n', length(tau_tdev));
catch ME
    fprintf('    TDEV failed: %s\n', ME.message);
end

try
    % Hadamard deviation
    fprintf('  Computing HDEV...\n');
    % Use subset for Hadamard (needs more points)
    hdev_m = m_values(m_values <= floor(N/6));
    [tau_hdev, hdev_vals, ~, ~] = hadvar(phase_data, tau0, hdev_m);
    results.hdev = struct('tau', tau_hdev, 'dev', sqrt(hdev_vals), 'm', hdev_m);
    fprintf('    HDEV: %d points\n', length(tau_hdev));
catch ME
    fprintf('    HDEV failed: %s\n', ME.message);
end

try
    % Total deviation
    fprintf('  Computing TOTDEV...\n');
    [tau_totdev, totdev_vals, ~, ~] = totvar(phase_data, tau0, m_values);
    results.totdev = struct('tau', tau_totdev, 'dev', sqrt(totdev_vals), 'm', m_values);
    fprintf('    TOTDEV: %d points\n', length(tau_totdev));
catch ME
    fprintf('    TOTDEV failed: %s\n', ME.message);
end

try
    % Modified total deviation
    fprintf('  Computing MTOTDEV...\n');
    [tau_mtotdev, mtotdev_vals, ~, ~] = mtotvar(phase_data, tau0, m_values);
    results.mtotdev = struct('tau', tau_mtotdev, 'dev', sqrt(mtotdev_vals), 'm', m_values);
    fprintf('    MTOTDEV: %d points\n', length(tau_mtotdev));
catch ME
    fprintf('    MTOTDEV failed: %s\n', ME.message);
end

try
    % Hadamard total deviation
    fprintf('  Computing HTOTDEV...\n');
    [tau_htotdev, htotdev_vals, ~, ~] = htotvar(phase_data, tau0, hdev_m);
    results.htotdev = struct('tau', tau_htotdev, 'dev', sqrt(htotdev_vals), 'm', hdev_m);
    fprintf('    HTOTDEV: %d points\n', length(tau_htotdev));
catch ME
    fprintf('    HTOTDEV failed: %s\n', ME.message);
end

try
    % Modified Hadamard deviation
    fprintf('  Computing MHDEV...\n');
    [tau_mhdev, mhdev_vals, ~, ~] = mhvar(phase_data, tau0, m_values);
    results.mhdev = struct('tau', tau_mhdev, 'dev', sqrt(mhdev_vals), 'm', m_values);
    fprintf('    MHDEV: %d points\n', length(tau_mhdev));
catch ME
    fprintf('    MHDEV failed: %s\n', ME.message);
end

try
    % Modified Hadamard total deviation
    fprintf('  Computing MHTOTDEV...\n');
    [tau_mhtotdev, mhtotdev_vals, ~, ~] = mhtotvar(phase_data, tau0, m_values);
    results.mhtotdev = struct('tau', tau_mhtotdev, 'dev', sqrt(mhtotdev_vals), 'm', m_values);
    fprintf('    MHTOTDEV: %d points\n', length(tau_mhtotdev));
catch ME
    fprintf('    MHTOTDEV failed: %s\n', ME.message);
end

fprintf('MATLAB computation complete.\n');

end

function write_json_file(filename, data)
%WRITE_JSON_FILE Write MATLAB structure to JSON file
%
% This is a simple JSON writer for MATLAB structures.
% For complex nested structures, consider using jsonencode (R2016b+).

try
    % Try using built-in jsonencode (MATLAB R2016b+)
    json_str = jsonencode(data);
catch
    % Fallback for older MATLAB versions
    json_str = struct_to_json(data);
end

% Write to file
fid = fopen(filename, 'w');
if fid == -1
    error('Could not open file for writing: %s', filename);
end

fprintf(fid, '%s', json_str);
fclose(fid);

end

function json_str = struct_to_json(s, indent)
%STRUCT_TO_JSON Convert MATLAB structure to JSON string (fallback)

if nargin < 2
    indent = 0;
end

ind_str = repmat('  ', 1, indent);
json_str = '';

if isstruct(s)
    json_str = [json_str, '{\n'];
    fields = fieldnames(s);
    for i = 1:length(fields)
        field = fields{i};
        value = s.(field);
        json_str = [json_str, ind_str, '  "', field, '": '];
        if isstruct(value)
            json_str = [json_str, struct_to_json(value, indent + 1)];
        elseif isnumeric(value)
            if length(value) == 1
                json_str = [json_str, num2str(value, '%.10e')];
            else
                json_str = [json_str, '[', sprintf('%.10e, ', value(1:end-1)), sprintf('%.10e', value(end)), ']'];
            end
        elseif ischar(value)
            json_str = [json_str, '"', value, '"'];
        end
        if i < length(fields)
            json_str = [json_str, ','];
        end
        json_str = [json_str, '\n'];
    end
    json_str = [json_str, ind_str, '}'];
elseif isnumeric(s)
    if length(s) == 1
        json_str = num2str(s, '%.10e');
    else
        json_str = ['[', sprintf('%.10e, ', s(1:end-1)), sprintf('%.10e', s(end)), ']'];
    end
elseif ischar(s)
    json_str = ['"', s, '"'];
end

end