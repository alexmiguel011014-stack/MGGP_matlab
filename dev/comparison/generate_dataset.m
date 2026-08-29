% generate_dataset.m — Gera siso_ref.csv para comparação MATLAB vs Python.
%
% Sistema: y(k) = 0.75*y(k-2) + 0.25*u1(k-1) - 0.20*y(k-2)*u1(k-1)
% N = 1000 amostras, rng(42), split 70/30 (id/val).
%
% Saída: data/siso_ref.csv  (colunas: y, u1)
%
% Executar de dev/comparison/:  run generate_dataset

scriptDir = fileparts(mfilename('fullpath'));
dataDir   = fullfile(scriptDir, 'data');
if ~exist(dataDir, 'dir'), mkdir(dataDir); end

rng(42);
N  = 1000;
u1 = randn(N, 1);
y  = zeros(N, 1);

for k = 3:N
    y(k) = 0.75*y(k-2) + 0.25*u1(k-1) - 0.20*y(k-2)*u1(k-1);
end

T = table(y, u1);
csvPath = fullfile(dataDir, 'siso_ref.csv');
writetable(T, csvPath);
fprintf('Gerado: %s  (%d amostras)\n', csvPath, N);
fprintf('Split: %d id / %d val\n', round(0.7*N), N - round(0.7*N));
