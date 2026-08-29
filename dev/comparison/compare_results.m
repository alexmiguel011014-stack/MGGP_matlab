% compare_results.m — Lê os JSON de bench_python.py e bench_matlab_vs_python.m
% e imprime uma tabela de comparação Markdown.
%
% Executar de dev/comparison/ depois de gerar ambos os JSONs:
%   run compare_results

scriptDir  = fileparts(mfilename('fullpath'));
RESULTS_DIR = fullfile(scriptDir, 'results');

%% ─── FIND LATEST JSON FILES ──────────────────────────────────────────────────
pyFiles  = dir(fullfile(RESULTS_DIR, 'python_bench_*.json'));
matFiles = dir(fullfile(RESULTS_DIR, 'matlab_bench_*.json'));

if isempty(pyFiles)
    error('compare_results:noPython', ...
        'Nenhum python_bench_*.json em %s\nExecute bench_python.py primeiro.', RESULTS_DIR);
end
if isempty(matFiles)
    error('compare_results:noMatlab', ...
        'Nenhum matlab_bench_*.json em %s\nExecute bench_matlab_vs_python.m primeiro.', RESULTS_DIR);
end

% pick the most recent of each
[~, pi] = max([pyFiles.datenum]);
[~, mi] = max([matFiles.datenum]);

pyPath  = fullfile(RESULTS_DIR, pyFiles(pi).name);
matPath = fullfile(RESULTS_DIR, matFiles(mi).name);

fprintf('Python : %s\n', pyFiles(pi).name);
fprintf('MATLAB : %s\n', matFiles(mi).name);

%% ─── READ JSON ───────────────────────────────────────────────────────────────
pyData  = jsondecode(fileread(pyPath));
matData = jsondecode(fileread(matPath));

% Python means
py = pyData.mean;

% MATLAB seq means
mat_seq = struct();
fields  = {'wall_s','tpg_ms','throughput_eps','osa_rmse_val','fr_rmse_val'};
for fi = 1:numel(fields)
    vals = zeros(numel(matData.seq), 1);
    for si = 1:numel(matData.seq)
        vals(si) = matData.seq{si}.(fields{fi});
    end
    mat_seq.(fields{fi}) = mean(vals, 'omitnan');
end

% MATLAB par means
mat_par = struct();
for fi = 1:numel(fields)
    vals = zeros(numel(matData.par), 1);
    for si = 1:numel(matData.par)
        vals(si) = matData.par{si}.(fields{fi});
    end
    mat_par.(fields{fi}) = mean(vals, 'omitnan');
end

%% ─── QUALITY PARITY CHECK ────────────────────────────────────────────────────
THRESHOLD = 1.20;   % MATLAB FR-RMSE ≤ Python FR-RMSE × 1.20

py_fr  = py.fr_rmse_val;
seq_fr = mat_seq.fr_rmse_val;
par_fr = mat_par.fr_rmse_val;

pass_seq = seq_fr <= py_fr * THRESHOLD;
pass_par = par_fr <= py_fr * THRESHOLD;

%% ─── PRINT COMPARISON TABLE ──────────────────────────────────────────────────
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('MATLAB vs Python MGGP — Comparison Results\n');
fprintf('(mean over %d seeds; see PROTOCOL.md for hyperparameter mapping)\n', ...
    numel(matData.seq));
fprintf('%s\n\n', repmat('=', 1, 72));

fprintf('| %-24s | %12s | %14s | %14s |\n', ...
    'Metric', 'Python (CPU)', 'MATLAB (seq)', 'MATLAB (par)');
fprintf('|%s|%s|%s|%s|\n', ...
    repmat('-',1,26), repmat('-',1,14), repmat('-',1,16), repmat('-',1,16));

rows = { ...
    'Wall time (s)',        py.wall_s,         mat_seq.wall_s,         mat_par.wall_s; ...
    'Time/gen (ms)',        py.tpg_ms,         mat_seq.tpg_ms,         mat_par.tpg_ms; ...
    'Throughput (eval/s)', py.throughput_eps,  mat_seq.throughput_eps, mat_par.throughput_eps; ...
    'OSA-RMSE (val)',       py.osa_rmse_val,   mat_seq.osa_rmse_val,   mat_par.osa_rmse_val; ...
    'FR-RMSE (val)',        py.fr_rmse_val,    mat_seq.fr_rmse_val,    mat_par.fr_rmse_val; ...
};

for ri = 1:size(rows, 1)
    label = rows{ri, 1};
    pv    = rows{ri, 2};
    sv    = rows{ri, 3};
    parv  = rows{ri, 4};
    fprintf('| %-24s | %12.4f | %14.4f | %14.4f |\n', label, pv, sv, parv);
end

fprintf('\n');

%% ─── SPEEDUP ─────────────────────────────────────────────────────────────────
su_seq = py.wall_s / mat_seq.wall_s;
su_par = py.wall_s / mat_par.wall_s;
fprintf('Speedup MATLAB-seq vs Python : %.2fx\n', su_seq);
fprintf('Speedup MATLAB-par vs Python : %.2fx\n', su_par);
fprintf('Speedup MATLAB-par vs MATLAB-seq: %.2fx\n', mat_seq.wall_s / mat_par.wall_s);

%% ─── QUALITY GATE ────────────────────────────────────────────────────────────
fprintf('\nQuality parity (FR-RMSE ≤ Python × %.0f%%):\n', THRESHOLD*100 - 100);
fprintf('  MATLAB-seq: %.6f  [%s]\n', seq_fr, ternary(pass_seq,'PASS','FAIL'));
fprintf('  MATLAB-par: %.6f  [%s]\n', par_fr, ternary(pass_par,'PASS','FAIL'));

fprintf('\nPython FR-RMSE threshold (× %.2f): %.6f\n', THRESHOLD, py_fr * THRESHOLD);

%% ─── KNOWN STRUCTURAL DIFFERENCES REMINDER ──────────────────────────────────
fprintf('\n%s\n', repmat('-', 1, 72));
fprintf('NOTE: results are NOT comparable at the model structure level (see PROTOCOL.md):\n');
fprintf('  G4-A1: Python q_i ≈ MATLAB q_{i+1} (lag offset)\n');
fprintf('  G4-A2: Python uses GP trees; MATLAB uses flat products\n');
fprintf('  Comparison is valid only for quality metrics (RMSE) and timing.\n');
fprintf('%s\n', repmat('-', 1, 72));


%% ─── HELPER ─────────────────────────────────────────────────────────────────
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
