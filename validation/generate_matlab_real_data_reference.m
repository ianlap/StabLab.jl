function generate_matlab_real_data_reference()
%GENERATE_MATLAB_REAL_DATA_REFERENCE Generate MATLAB reference using real test datasets
%
% Uses the actual data files: 6krb25apr.txt, 6krbsnip.txt, mx.w10.pem7

fprintf('Generating MATLAB reference data for real datasets...\n');

% Add AllanLab to path
matlab_allanlab_path = '/Users/ianlapinski/Desktop/masterclock-kflab/matlab/AllanLab';
if exist(matlab_allanlab_path, 'dir')
    addpath(genpath(matlab_allanlab_path));
    fprintf('Added AllanLab path: %s\n', matlab_allanlab_path);
else
    error('AllanLab path not found: %s', matlab_allanlab_path);
end

% Data file definitions
data_dir = '../data';
test_files = struct();
test_files(1).name = '6krb25apr';
test_files(1).filepath = fullfile(data_dir, '6krb25apr.txt');
test_files(1).tau0 = 1.0;
test_files(1).description = 'Rubidium clock full dataset';

test_files(2).name = '6krbsnip';
test_files(2).filepath = fullfile(data_dir, '6krbsnip.txt');
test_files(2).tau0 = 1.0;
test_files(2).description = 'Rubidium clock snippet';

test_files(3).name = 'mx_w10_pem7';
test_files(3).filepath = fullfile(data_dir, 'mx.w10.pem7');
test_files(3).tau0 = 1.0;
test_files(3).description = 'GPS receiver data';

% Output directory
output_dir = '.';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Process each dataset
all_results = struct();

for i = 1:length(test_files)
    dataset = test_files(i);
    
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('Processing %s: %s\n', dataset.name, dataset.description);
    fprintf('%s\n', repmat('=', 1, 60));
    
    try
        % Load phase data
        if ~exist(dataset.filepath, 'file')
            fprintf('Warning: File not found: %s\n', dataset.filepath);
            fprintf('Skipping this dataset...\n');
            continue;
        end
        
        phase_data = load_phase_data(dataset.filepath);
        fprintf('Loaded %d data points\n', length(phase_data));
        fprintf('Range: [%.3e, %.3e]\n', min(phase_data), max(phase_data));
        
        % Compute MATLAB deviations
        results = compute_matlab_deviations(phase_data, dataset.tau0, dataset.name);
        
        if isempty(fieldnames(results))
            fprintf('Warning: No results computed for %s\n', dataset.name);
            continue;
        end
        
        % Save individual results file
        output_file = fullfile(output_dir, sprintf('matlab_reference_%s.json', dataset.name));
        
        % Create metadata
        metadata = struct();
        metadata.dataset = dataset.name;
        metadata.description = dataset.description;
        metadata.filepath = dataset.filepath;
        metadata.N = length(phase_data);
        metadata.tau0 = dataset.tau0;
        metadata.matlab_version = version();
        metadata.data_type = 'phase';
        metadata.data_range = [min(phase_data), max(phase_data)];
        metadata.data_statistics = struct();
        metadata.data_statistics.mean = mean(phase_data);
        metadata.data_statistics.std = std(phase_data);
        metadata.data_statistics.duration_seconds = length(phase_data) * dataset.tau0;
        
        output_data = struct();
        output_data.metadata = metadata;
        output_data.results = results;
        
        % Write JSON file
        write_json_file(output_file, output_data);
        
        fprintf('Saved: %s\n', output_file);
        func_names = fieldnames(results);
        fprintf('Functions computed: %s\n', strjoin(func_names, ', '));
        
        % Store in combined results
        all_results.(dataset.name) = output_data;
        
        % Save subset of phase data for Julia (first 10000 points)
        max_points = 10000;
        if length(phase_data) > max_points
            phase_subset = phase_data(1:max_points);
            fprintf('Note: Saved first %d points of %d for Julia comparison\n', max_points, length(phase_data));
        else
            phase_subset = phase_data;
        end
        
        data_file = fullfile(output_dir, sprintf('phase_data_%s.json', dataset.name));
        phase_data_struct = struct();
        phase_data_struct.phase_data = phase_subset;
        phase_data_struct.tau0 = dataset.tau0;
        phase_data_struct.N_original = length(phase_data);
        phase_data_struct.N_subset = length(phase_subset);
        phase_data_struct.dataset = dataset.name;
        phase_data_struct.description = dataset.description;
        
        write_json_file(data_file, phase_data_struct);
        fprintf('Saved phase data: %s\n', data_file);
        
    catch ME
        fprintf('Error processing %s: %s\n', dataset.name, ME.message);
        continue;
    end
end

% Create combined reference file
if ~isempty(fieldnames(all_results))
    combined_file = fullfile(output_dir, 'all_datasets_matlab_reference.json');
    write_json_file(combined_file, all_results);
    fprintf('\nSaved combined results: %s\n', combined_file);
end

fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('MATLAB reference generation complete!\n');
fprintf('%s\n', repmat('=', 1, 60));
datasets = fieldnames(all_results);
fprintf('Processed datasets: %s\n', strjoin(datasets, ', '));

end

function phase_data = load_phase_data(filename)
%LOAD_PHASE_DATA Load phase data from text file

fprintf('Loading %s...\n', filename);

% Read file
try
    data = readmatrix(filename);
    
    % Take first column if multiple columns
    if size(data, 2) > 1
        phase_data = data(:, 1);
    else
        phase_data = data;
    end
    
    % Remove NaN values
    phase_data = phase_data(~isnan(phase_data));
    
    if isempty(phase_data)
        error('No valid data found in file');
    end
    
catch ME
    % Fallback: try reading line by line
    fprintf('  Matrix read failed, trying line-by-line parsing...\n');
    
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    
    phase_data = [];
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && ~isempty(line) && ~startsWith(line, '#') && ~startsWith(line, '%')
            try
                value = str2double(strtrim(line));
                if ~isnan(value)
                    phase_data(end+1) = value; %#ok<AGROW>
                end
            catch
                continue;
            end
        end
    end
    fclose(fid);
    
    if isempty(phase_data)
        error('No valid numerical data found in file');
    end
    
    phase_data = phase_data(:); % Ensure column vector
end

fprintf('  Loaded %d data points\n', length(phase_data));

end

function results = compute_matlab_deviations(phase_data, tau0, dataset_name)
%COMPUTE_MATLAB_DEVIATIONS Compute all deviations using MATLAB AllanLab

results = struct();
N = length(phase_data);

% Conservative tau list for real data
max_m = min(floor(N/20), 1000);  % Conservative limit
m_values = unique(round(logspace(0, log10(max_m), 25)));
tau_values = m_values * tau0;

fprintf('Computing MATLAB deviations for %s...\n', dataset_name);
fprintf('N=%d points, tau range: %.1f to %.1f seconds (%d points)\n', ...
        N, min(tau_values), max(tau_values), length(tau_values));

% List of deviation functions to compute
deviation_functions = {
    {'adev', @allanvar, 'Allan Deviation'},
    {'mdev', @modvar, 'Modified Allan Deviation'},
    {'tdev', @timevar, 'Time Deviation'},
    {'totdev', @totvar, 'Total Deviation'},
    {'mtotdev', @mtotvar, 'Modified Total Deviation'},
    {'mhdev', @mhvar, 'Modified Hadamard Deviation'},
    {'mhtotdev', @mhtotvar, 'Modified Hadamard Total Deviation'}
};

% Functions requiring smaller m values
hadamard_functions = {
    {'hdev', @hadvar, 'Hadamard Deviation'},
    {'htotdev', @htotvar, 'Hadamard Total Deviation'}
};

% Compute standard deviations
for i = 1:length(deviation_functions)
    func_info = deviation_functions{i};
    func_name = func_info{1};
    func_handle = func_info{2};
    description = func_info{3};
    
    try
        fprintf('  Computing %s (%s)...\n', func_name, description);
        
        [tau_vals, var_vals, ~, ~] = func_handle(phase_data, tau0, m_values);
        
        results.(func_name) = struct();
        results.(func_name).tau = tau_vals;
        results.(func_name).dev = sqrt(var_vals);
        results.(func_name).m = m_values;
        results.(func_name).description = description;
        
        fprintf('    ✓ %s: %d points\n', func_name, length(tau_vals));
        
    catch ME
        fprintf('    ✗ %s failed: %s\n', func_name, ME.message);
    end
end

% Compute Hadamard deviations with smaller m values
hdev_m = m_values(m_values <= floor(N/10));
if ~isempty(hdev_m)
    for i = 1:length(hadamard_functions)
        func_info = hadamard_functions{i};
        func_name = func_info{1};
        func_handle = func_info{2};
        description = func_info{3};
        
        try
            fprintf('  Computing %s (%s)...\n', func_name, description);
            
            [tau_vals, var_vals, ~, ~] = func_handle(phase_data, tau0, hdev_m);
            
            results.(func_name) = struct();
            results.(func_name).tau = tau_vals;
            results.(func_name).dev = sqrt(var_vals);
            results.(func_name).m = hdev_m;
            results.(func_name).description = description;
            
            fprintf('    ✓ %s: %d points\n', func_name, length(tau_vals));
            
        catch ME
            fprintf('    ✗ %s failed: %s\n', func_name, ME.message);
        end
    end
end

fprintf('MATLAB computation complete for %s.\n', dataset_name);

end

function write_json_file(filename, data)
%WRITE_JSON_FILE Write MATLAB structure to JSON file

try
    % Try using built-in jsonencode (MATLAB R2016b+)
    json_str = jsonencode(data);
catch
    % Fallback for older MATLAB versions
    error('jsonencode not available. Please use MATLAB R2016b or later.');
end

% Write to file
fid = fopen(filename, 'w');
if fid == -1
    error('Could not open file for writing: %s', filename);
end

fprintf(fid, '%s', json_str);
fclose(fid);

end