function bench_performance(opcoes)
%BENCH_PERFORMANCE Benchmarks de desempenho: speedup parfor, escalabilidade, breakdown.
%
%   BENCH_PERFORMANCE()        — todos os sub-benchmarks com config padrao
%   BENCH_PERFORMANCE(opcoes) — struct de overrides; campos:
%     runSpeedup    (true)  — §3a: sequencial vs parfor por popSize
%     runEscala     (true)  — §3b: escalabilidade com N
%     runBreakdown  (true)  — §3c: breakdown de tempo por fase
%     nSeeds        (3)     — sementes para calculo de media/std
%
%   Cada sub-benchmark salva um JSON em dev/benchmarks/results/.
%
%   REQUER: Parallel Computing Toolbox para runSpeedup e runBreakdown com parfor.

    if nargin < 1, opcoes = struct(); end
    doSpeedup   = campo(opcoes, 'runSpeedup',   true);
    doEscala    = campo(opcoes, 'runEscala',    true);
    doBreakdown = campo(opcoes, 'runBreakdown', true);
    nSeeds      = campo(opcoes, 'nSeeds',       3);

    % Dataset comum a todos os sub-benchmarks: sistema SISO, N=1000
    N = 2000;
    thetaV = [0.75; 0.25; -0.20];
    rng(42);
    u1_full = randn(N, 1);
    y_full  = zeros(N, 1);
    for k = 3:N
        y_full(k) = thetaV(1)*y_full(k-2) + thetaV(2)*u1_full(k-1) ...
                  + thetaV(3)*y_full(k-2)*u1_full(k-1);
    end

    % Config base
    cfgBase = struct('nomesEntradas', {{'u1'}}, 'maxDelay', 3, ...
        'maxFatoresPorTermo', 2, 'verbose', false);

    % --- §3a: Sequential vs parfor ---
    if doSpeedup
        fprintf('\n=== §3a: Speedup parfor por popSize ===\n');
        fprintf('%-10s %-10s %-10s %-10s %-10s\n', 'popSize', 't_seq(s)', 't_par(s)', 'speedup', 'workers');
        popSizes = [50, 100, 200];
        N_id = 700;
        vars_id = struct('y', y_full(1:N_id), 'u1', u1_full(1:N_id));
        resultadosSpeedup = cell(numel(popSizes), 1);

        for pi = 1:numel(popSizes)
            ps = popSizes(pi);
            t_seqs = zeros(1, nSeeds);
            t_pars = zeros(1, nSeeds);
            for si = 1:nSeeds
                cfg = cfgBase;
                cfg.vars = vars_id; cfg.popSize = ps; cfg.nGeracoes = 30;
                rng(40 + si);
                t0 = tic; cfg.usarParfor = false; evoluir(cfg); t_seqs(si) = toc(t0);
                rng(40 + si);
                t0 = tic; cfg.usarParfor = true;  evoluir(cfg); t_pars(si) = toc(t0);
            end
            tSeq = mean(t_seqs); tPar = mean(t_pars);
            speedup = tSeq / tPar;
            try, nW = gcp('nocreate').NumWorkers; catch, nW = NaN; end
            fprintf('%-10d %-10.2f %-10.2f %-10.2f %-10g\n', ps, tSeq, tPar, speedup, nW);
            resultadosSpeedup{pi} = struct('popSize', ps, 't_seq', tSeq, 't_par', tPar, ...
                'speedup', speedup, 'numWorkers', nW);
        end
        salvarBenchJson('perf_speedup', struct('resultados', {resultadosSpeedup}));
    end

    % --- §3b: Escalabilidade com N ---
    if doEscala
        fprintf('\n=== §3b: Escalabilidade com tamanho do dataset ===\n');
        fprintf('%-8s %-12s %-14s\n', 'N', 'total(s)', 'por_ind(ms)');
        tamanhos = [200, 500, 1000, 2000];
        cfg = cfgBase; cfg.popSize = 50; cfg.nGeracoes = 20; cfg.usarParfor = false;
        resultadosEscala = cell(numel(tamanhos), 1);

        for ni = 1:numel(tamanhos)
            Ni = tamanhos(ni);
            cfg.vars = struct('y', y_full(1:Ni), 'u1', u1_full(1:Ni));
            ts = zeros(1, nSeeds);
            for si = 1:nSeeds
                rng(40 + si); t0 = tic; evoluir(cfg); ts(si) = toc(t0);
            end
            tMedia = mean(ts);
            nAvals = cfg.popSize * cfg.nGeracoes;  % aprox (ignora elite reuso)
            tPorInd = tMedia / nAvals * 1000;
            fprintf('%-8d %-12.2f %-14.3f\n', Ni, tMedia, tPorInd);
            resultadosEscala{ni} = struct('N', Ni, 'total_s', tMedia, 'por_ind_ms', tPorInd);
        end
        salvarBenchJson('perf_escala', struct('resultados', {resultadosEscala}));
    end

    % --- §3c: Breakdown de tempo por fase ---
    if doBreakdown
        fprintf('\n=== §3c: Breakdown de tempo por fase ===\n');
        N_id = 700;
        vars_id = struct('y', y_full(1:N_id), 'u1', u1_full(1:N_id));
        cfg = cfgBase; cfg.vars = vars_id; cfg.popSize = 100; cfg.nGeracoes = 20;
        cfg.verbose_timing = true; cfg.usarParfor = false;
        fprintf('--- Sequencial ---\n');
        rng(42); evoluir(cfg);

        cfg.usarParfor = true;
        fprintf('--- Com parfor ---\n');
        rng(42); evoluir(cfg);
    end
end

function v = campo(s, nome, default)
    if isfield(s, nome), v = s.(nome); else, v = default; end
end
