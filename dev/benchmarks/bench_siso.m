function resultado = bench_siso(opcoes)
%BENCH_SISO Benchmark de identificacao do sistema SISO canonico.
%
%   resultado = BENCH_SISO() — config padrao (popSize=100, nGeracoes=50, 5 seeds)
%   resultado = BENCH_SISO(opcoes) — struct de overrides (qualquer campo abaixo)
%
%   Sistema gerador: y(k) = 0.75*y(k-2) + 0.25*u1(k-1) - 0.20*y(k-2)*u1(k-1)
%   N=1000 amostras, split 70/30 id/val, sementes 42..46.
%
%   Metricas reportadas por seed:
%     OSA-RMSE (id)  : erro one-step-ahead no conjunto de identificacao
%     OSA-RMSE (val) : erro one-step-ahead no conjunto de validacao
%     FR-RMSE  (val) : erro free-run no conjunto de validacao
%     numTermos      : complexidade do melhor modelo encontrado
%     modelo         : estrutura do melhor modelo (string)
%
%   Threshold de aprovacao: OSA-RMSE (val) < 0.01 em >= 3/5 seeds.
%
%   Salva resultado em dev/benchmarks/results/siso_<timestamp>.json.

    if nargin < 1, opcoes = struct(); end

    cfg.popSize           = campo(opcoes, 'popSize',           100);
    cfg.nGeracoes         = campo(opcoes, 'nGeracoes',         50);
    cfg.nSeeds            = campo(opcoes, 'nSeeds',            5);
    cfg.N                 = campo(opcoes, 'N',                 1000);
    cfg.maxDelay          = campo(opcoes, 'maxDelay',          3);
    cfg.maxFatoresPorTermo = campo(opcoes, 'maxFatoresPorTermo', 2);
    cfg.salvarJson        = campo(opcoes, 'salvarJson',        true);

    thetaVerdadeiro   = [0.75; 0.25; -0.20];
    estruturaRef      = 'q2(y) + q1(u1) + q2(y)*q1(u1)';
    N_id  = round(0.7 * cfg.N);

    fprintf('=== bench_siso | popSize=%d nGeracoes=%d seeds=%d..%d ===\n', ...
        cfg.popSize, cfg.nGeracoes, 42, 42 + cfg.nSeeds - 1);

    rmseOsaVals = zeros(1, cfg.nSeeds);
    linhas = cell(cfg.nSeeds, 1);

    for si = 1:cfg.nSeeds
        semente = 41 + si;
        rng(semente);

        u1 = randn(cfg.N, 1);
        y  = zeros(cfg.N, 1);
        for k = 3:cfg.N
            y(k) = thetaVerdadeiro(1)*y(k-2) + thetaVerdadeiro(2)*u1(k-1) ...
                 + thetaVerdadeiro(3)*y(k-2)*u1(k-1);
        end

        y_id  = y(1:N_id);      u1_id  = u1(1:N_id);
        y_val = y(N_id+1:end);  u1_val = u1(N_id+1:end);

        eCfg = struct();
        eCfg.vars               = struct('y', y_id, 'u1', u1_id);
        eCfg.nomesEntradas      = {'u1'};
        eCfg.maxDelay           = cfg.maxDelay;
        eCfg.maxFatoresPorTermo = cfg.maxFatoresPorTermo;
        eCfg.popSize            = cfg.popSize;
        eCfg.nGeracoes          = cfg.nGeracoes;
        eCfg.verbose            = false;

        [melhorModelo, melhorTheta, ~] = evoluir(eCfg);

        % OSA-RMSE identificacao
        mseId = scoreOsa(melhorTheta, melhorModelo.compile(), eCfg.vars, melhorModelo.maiorAtraso());

        % OSA-RMSE validacao
        vars_val = struct('y', y_val, 'u1', u1_val);
        mseVal   = scoreOsa(melhorTheta, melhorModelo.compile(), vars_val, melhorModelo.maiorAtraso());

        % Free-run RMSE validacao
        maxLag = melhorModelo.maiorAtraso();
        y0     = y_id(max(1, end - maxLag + 1) : end);
        y_fr   = melhorModelo.simularFreeRun(melhorTheta, y0, struct('u1', u1_val));
        y_sim  = y_fr(numel(y0)+1 : end);
        rmseFr = sqrt(mean((y_val - y_sim).^2));

        rmseOsaVals(si) = sqrt(mseVal);
        linhas{si} = struct('semente', semente, ...
            'rmseOsaId', sqrt(mseId), 'rmseOsaVal', sqrt(mseVal), ...
            'rmseFreeRunVal', rmseFr, 'numTermos', melhorModelo.numTermos(), ...
            'maiorAtraso', melhorModelo.maiorAtraso(), 'modelo', melhorModelo.toString());

        fprintf('seed %d | OSA-RMSE id=%.4g val=%.4g | FR-RMSE=%.4g | %d termos | %s\n', ...
            semente, sqrt(mseId), sqrt(mseVal), rmseFr, ...
            melhorModelo.numTermos(), melhorModelo.toString());
    end

    nPassou = sum(rmseOsaVals < 0.01);
    fprintf('\n--- Sumario ---\n');
    fprintf('OSA-RMSE val: media=%.4g  std=%.4g  min=%.4g  max=%.4g\n', ...
        mean(rmseOsaVals), std(rmseOsaVals), min(rmseOsaVals), max(rmseOsaVals));
    fprintf('Estrutura verdadeira: %s\n', estruturaRef);
    fprintf('Threshold OSA-RMSE val < 0.01: %d/%d seeds aprovaram\n', nPassou, cfg.nSeeds);

    resultado = struct('config', cfg, 'resultados', {linhas}, ...
        'rmseOsaValMedia', mean(rmseOsaVals), 'nSeedsPassaram', nPassou);

    if cfg.salvarJson
        salvarBenchJson('siso', resultado);
    end
end

function v = campo(s, nome, default)
    if isfield(s, nome), v = s.(nome); else, v = default; end
end
