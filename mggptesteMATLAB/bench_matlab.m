% bench_matlab.m — Competicao de bibliotecas MGGP — lado MATLAB.
%
% Parametros fixados conforme configuracao da competicao.
% Saida em: .\resultados\
%
% Metricas registradas por modelo:
%   Qualidade   : FreeRun RMSE (Vx, Vy) nas 4 trilhas Wang
%   Tempo       : tempo_treino_s (wall-clock)
%   Custo       : n_avaliacoes (estimado: popSize + (popSize-nElite)*nGeracoes, por saida)
%   Convergencia: fitness_inicial, fitness_final, geracao_melhor, taxa_melhoria_pct
%   Complexidade: n_termos_modelo, max_lag_modelo
%
% Diferencas estruturais vs Python (ver CLAUDE.md G4-A1..A4):
%   - Python nDelays=[1,2,5,10,25,50] -> MATLAB maxDelay=50 (superset q1..q50)
%   - Python usa arvores GP com operadores add/sub/mul (maxHeight=7)
%   - MATLAB usa produtos planos de fatores lineares (maxFatoresPorTermo=7)

clear; clc;

%% ─── CAMINHOS ────────────────────────────────────────────────────────────────
scriptDir   = fileparts(mfilename('fullpath'));
DB_DIR      = 'D:\ProjetosPessoais\IC\Database';
RESULTS_DIR = fullfile(scriptDir, 'resultados');
MATLAB_SRC  = fullfile(scriptDir, 'src');

if ~exist(RESULTS_DIR, 'dir'), mkdir(RESULTS_DIR); end
if ~exist('evoluirMimo', 'file'), addpath(MATLAB_SRC); end

%% ─── PARAMETROS FIXOS DA COMPETICAO ─────────────────────────────────────────
MAX_TENTATIVAS = 50;
META_MODELOS   = 10;
RMSE_MIN       = 0.0;
RMSE_MAX       = 100.0;

% Colunas do Excel (1-indexed = pandas 0-indexed + 1)
U_COLS = [15, 3, 23, 24, 12];   % 5 entradas
Y_COLS = [19, 18];               % [Vx, Vy]

trackNames = {'wang21', 'wang22', 'wang31', 'wang81'};
trackFiles = {
    fullfile(DB_DIR, 'wang21dv_bic_MGGP.xlsx'),   % treino
    fullfile(DB_DIR, 'wang22dv_bic_MGGP.xlsx'),   % validacao
    fullfile(DB_DIR, 'wang31dv_bic_MGGP.xlsx'),   % teste A
    fullfile(DB_DIR, 'wang81dv_bic_MGGP.xlsx'),   % teste B
};

%% ─── CARREGA DADOS ───────────────────────────────────────────────────────────
fprintf('Carregando dados...\n');
nTracks = numel(trackFiles);
trackU  = cell(1, nTracks);
trackY  = cell(1, nTracks);
for i = 1:nTracks
    T = readtable(trackFiles{i});
    trackU{i} = T{:, U_COLS};
    trackY{i} = T{:, Y_COLS};
end
u_train = trackU{1};
y_train = trackY{1};
fprintf('Treino (Wang 2.1): %d amostras, %d entradas, %d saidas\n\n', ...
    size(y_train,1), size(u_train,2), size(y_train,2));

%% ─── CONFIG BASE ─────────────────────────────────────────────────────────────
% nDelays Python [1,2,5,10,25,50] -> maxDelay=50 no MATLAB (q1..q50 disponíveis)
% maxHeight Python 7 -> maxFatoresPorTermo=7 no MATLAB (produtos de ate 7 fatores)
config.popSize              = 300;
config.nGeracoes            = 300;
config.cxpb                 = 0.8;
config.mtpb                 = 0.3;
config.tamanhoTorneio       = 2;
config.elite                = 0.10;
config.maxDelay             = 50;
config.maxFatoresPorTermo   = 7;
config.numTermosInicial     = 7;
config.tipoFitness          = 'mShooting';
config.janelaMShooting      = 300;
config.verbose              = true;
config.verbose_timing       = false;
config.usarParfor           = true;    % parfor na avaliação de fitness (exige PCT)
config.nomesOutputs         = {'y1', 'y2'};
config.nomesEntradas        = {'u1', 'u2', 'u3', 'u4', 'u5'};

nElite = round(config.popSize * config.elite);   % para estimativa de n_avaliacoes

%% ─── FABRICA ─────────────────────────────────────────────────────────────────
resultRows = cell(META_MODELOS, 1);
n_aceitos  = 0;
tentativa  = 0;

while n_aceitos < META_MODELOS && tentativa < MAX_TENTATIVAS
    tentativa = tentativa + 1;
    fprintf('--- Tentativa %d  (aceitos: %d/%d) ---\n', tentativa, n_aceitos, META_MODELOS);
    t0 = tic;

    try
        config.vars    = struct();
        config.vars.y1 = y_train(:, 1);
        config.vars.y2 = y_train(:, 2);
        for k = 1:5
            config.vars.(sprintf('u%d', k)) = u_train(:, k);
        end

        [modelos, thetas, historicos] = evoluirMimo(config);
        tempo_s = toc(t0);

        maxLag = 0;
        for i = 1:numel(modelos)
            for j = 1:numel(modelos{i}.termos)
                maxLag = max(maxLag, modelos{i}.termos(j).maiorAtraso());
            end
        end
        maxLag = max(maxLag, 1);

        [rv, ry] = freerun_rmse(modelos, thetas, y_train, u_train, maxLag, config.nomesOutputs);
        rmse_train = (rv + ry) / 2;
        fprintf('  FreeRun treino: Vx=%.4f  Vy=%.4f  mean=%.4f  t=%.0fs\n', rv, ry, rmse_train, tempo_s);

        if rmse_train <= RMSE_MIN || rmse_train >= RMSE_MAX
            fprintf('  Rejeitado.\n');
            continue;
        end

        n_aceitos = n_aceitos + 1;

        mon = extrair_monitoramento(historicos, modelos, maxLag, tempo_s, ...
                                    config.popSize, config.nGeracoes, nElite);
        fprintf('  [OK] Modelo %d | gen_melhor=%d | evals=%d | melhoria=%.1f%%\n', ...
            n_aceitos, mon.geracao_melhor, mon.n_avaliacoes, mon.taxa_melhoria_pct);

        row = struct( ...
            'library',           'matlab',  ...
            'model_id',          n_aceitos, ...
            'wang21_vx',         rv,        ...
            'wang21_vy',         ry,        ...
            'wang22_vx',         NaN,       ...
            'wang22_vy',         NaN,       ...
            'wang31_vx',         NaN,       ...
            'wang31_vy',         NaN,       ...
            'wang81_vx',         NaN,       ...
            'wang81_vy',         NaN,       ...
            'tempo_treino_s',    mon.tempo_treino_s,    ...
            'n_avaliacoes',      mon.n_avaliacoes,      ...
            'fitness_inicial',   mon.fitness_inicial,   ...
            'fitness_final',     mon.fitness_final,     ...
            'geracao_melhor',    mon.geracao_melhor,    ...
            'taxa_melhoria_pct', mon.taxa_melhoria_pct, ...
            'n_termos_modelo',   mon.n_termos_modelo,   ...
            'max_lag_modelo',    maxLag                  ...
        );

        for i = 2:nTracks
            [rvi, ryi] = freerun_rmse(modelos, thetas, trackY{i}, trackU{i}, ...
                                      maxLag, config.nomesOutputs);
            row.(sprintf('%s_vx', trackNames{i})) = rvi;
            row.(sprintf('%s_vy', trackNames{i})) = ryi;
            fprintf('  %s: Vx=%.4f  Vy=%.4f\n', trackNames{i}, rvi, ryi);
        end

        resultRows{n_aceitos} = row;

        matPath = fullfile(RESULTS_DIR, sprintf('model_matlab_id%d.mat', n_aceitos));
        save(matPath, 'modelos', 'thetas', 'maxLag');

        convPath = fullfile(RESULTS_DIR, sprintf('conv_matlab_id%d.csv', n_aceitos));
        writetable(mon.conv_table, convPath);

    catch err
        fprintf('  ERRO: %s\n', err.message);
    end
end

%% ─── SALVA CSV PRINCIPAL ─────────────────────────────────────────────────────
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('Finalizou: %d/%d modelos em %d tentativas.\n', n_aceitos, META_MODELOS, tentativa);
fprintf('Taxa de aceitacao: %.1f%%\n', n_aceitos/tentativa*100);

if n_aceitos > 0
    T_out = struct2table([resultRows{1:n_aceitos}]);

    varNames = T_out.Properties.VariableNames;
    numVars  = varNames(~ismember(varNames, {'library', 'model_id'}));

    rowMean = table2struct(T_out(1,:));  rowMean.library = 'matlab_MEAN'; rowMean.model_id = 0;
    rowStd  = table2struct(T_out(1,:));  rowStd.library  = 'matlab_STD';  rowStd.model_id  = 0;
    for k = 1:numel(numVars)
        v = T_out.(numVars{k});
        rowMean.(numVars{k}) = mean(v, 'omitnan');
        rowStd.(numVars{k})  = std(v,  'omitnan');
    end
    T_out = [T_out; struct2table(rowMean); struct2table(rowStd)];

    csvPath = fullfile(RESULTS_DIR, 'resultados_matlab.csv');
    writetable(T_out, csvPath);
    fprintf('Resultados: %s\n', csvPath);
    disp(T_out);
end


%% ═══════════════════════════════════════════════════════════════════════════════
%% FUNCOES AUXILIARES
%% ═══════════════════════════════════════════════════════════════════════════════

function [rmse_vx, rmse_vy] = freerun_rmse(modelos, thetas, y, u, maxLag, nomesOutputs)
    N = size(y, 1);
    if maxLag >= N, rmse_vx = Inf; rmse_vy = Inf; return; end

    Y0 = y(1:maxLag, :);
    inputs = struct();
    for k = 1:size(u, 2)
        inputs.(sprintf('u%d', k)) = u(maxLag+1:end, k);
    end

    try
        Ys     = predictFreeRunMimo(modelos, thetas, Y0, inputs, nomesOutputs);
        y_pred = Ys(maxLag+1:end, :);
        y_true = y(maxLag+1:end, :);
        n      = min(size(y_pred,1), size(y_true,1));
        rmse_vx = sqrt(mean((y_true(1:n,1) - y_pred(1:n,1)).^2));
        rmse_vy = sqrt(mean((y_true(1:n,2) - y_pred(1:n,2)).^2));
    catch err
        warning('bench_matlab:freeRunFail', '%s', err.message);
        rmse_vx = Inf; rmse_vy = Inf;
    end
end


function mon = extrair_monitoramento(historicos, modelos, maxLag, tempo_s, popSize, nGeracoes, nElite)
    nOut = numel(historicos);
    nGer = numel(historicos{1});

    fit_hist  = zeros(nGer, nOut);
    med_hist  = zeros(nGer, nOut);
    geracoes  = zeros(nGer, 1);
    for oi = 1:nOut
        for g = 1:numel(historicos{oi})
            fit_hist(g, oi) = historicos{oi}(g).melhorFitness;
            med_hist(g, oi) = historicos{oi}(g).fitnessMedio;
            geracoes(g)     = historicos{oi}(g).geracao;
        end
    end
    mean_best = mean(fit_hist, 2, 'omitnan');
    mean_med  = mean(med_hist, 2, 'omitnan');

    fitness_inicial = mean_best(1);
    fitness_final   = mean_best(end);

    best_val       = fitness_inicial;
    geracao_melhor = geracoes(1);
    for g = 2:nGer
        if isfinite(mean_best(g)) && mean_best(g) < best_val * 0.99
            best_val       = mean_best(g);
            geracao_melhor = geracoes(g);
        end
    end

    if isfinite(fitness_inicial) && fitness_inicial > 0
        taxa_melhoria_pct = (fitness_inicial - fitness_final) / fitness_inicial * 100;
    else
        taxa_melhoria_pct = NaN;
    end

    n_avaliacoes = nOut * (popSize + (popSize - nElite) * nGeracoes);

    n_termos_modelo = 0;
    for oi = 1:numel(modelos)
        n_termos_modelo = n_termos_modelo + numel(modelos{oi}.termos);
    end

    conv_table = table(geracoes, mean_best, mean_med, ...
        'VariableNames', {'geracao', 'melhor_fitness', 'fitness_medio'});

    mon = struct( ...
        'tempo_treino_s',    round(tempo_s, 2),            ...
        'n_avaliacoes',      n_avaliacoes,                  ...
        'fitness_inicial',   round(fitness_inicial, 6),     ...
        'fitness_final',     round(fitness_final, 6),       ...
        'geracao_melhor',    geracao_melhor,                 ...
        'taxa_melhoria_pct', round(taxa_melhoria_pct, 2),   ...
        'n_termos_modelo',   n_termos_modelo,               ...
        'conv_table',        conv_table                      ...
    );
end
