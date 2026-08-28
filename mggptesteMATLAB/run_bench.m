% run_bench.m — Ponto de entrada para o benchmark MATLAB.
% Execute este script a partir da pasta mggptesteMATLAB no MATLAB.

scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, 'src'));
cd(scriptDir);
bench_matlab;
