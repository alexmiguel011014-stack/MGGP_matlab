function resultado = bench_miso(opcoes)
%BENCH_MISO Benchmark de identificacao de sistema MISO (duas entradas).
%
%   resultado = BENCH_MISO()        — config padrao
%   resultado = BENCH_MISO(opcoes) — struct de overrides
%
%   Sistema gerador: y(k) = 0.5*y(k-1) + 0.3*u1(k-1) - 0.15*u2(k-1)*y(k-1)
%   N=800 amostras, split 70/30 id/val, sementes 42..46.
%
%   Valida o caminho MISO end-to-end: struct com campos u1 e u2,
%   nomesEntradas = {'u1','u2'}, makeregressors usando ambas as entradas.

    if nargin < 1, opcoes = struct(); end

    cfg.popSize           = campo(opcoes, 'popSize',           100);
    cfg.nGeracoes         = campo(opcoes, 'nGeracoes',         50);
    cfg.nSeeds            = campo(opcoes, 'nSeeds',            5);
    cfg.N                 = campo(opcoes, 'N',                 800);
    cfg.maxDelay          = campo(opcoes, 'maxDelay',          3);
    cfg.maxFatoresPorTermo = campo(opcoes, 'maxFatoresPorTermo', 2);
    cfg.salvarJson        = campo(opcoes, 'salvarJson',        true);

    thetaVerdadeiro = [0.5; 0.3; -0.15];
    estruturaRef    = 'q1(y) + q1(u1) + q1(u2)*q1(y)';
    N_id = round(0.7 * cfg.N);

    fprintf('=== bench_miso | popSize=%d nGeracoes=%d seeds=%d..%d ===\n', ...
        cfg.popSize, cfg.nGeracoes, 42, 42 + cfg.nSeeds - 1);

    rmseOsaVals = zeros(1, cfg.nSeeds);
    linhas = cell(cfg.nSeeds, 1);

    for si = 1:cfg.nSeeds
        semente = 41 + si;
        rng(semente);

        u1 = randn(cfg.N, 1);
        u2 = randn(cfg.N, 1);
        y  = zeros(cfg.N, 1);
        for k = 2:cfg.N
            y(k) = thetaVerdadeiro(1)*y(k-1) + thetaVerdadeiro(2)*u1(k-1) ...
                 + thetaVerdadeiro(3)*u2(k-1)*y(k-1);
        end

        y_id   = y(1:N_id);      u1_id  = u1(1:N_id);   u2_id  = u2(1:N_id);
        y_val  = y(N_id+1:end);  u1_val = u1(N_id+1:end); u2_val = u2(N_id+1:end);

        eCfg = struct();
        eCfg.vars               = struct('y', y_id, 'u1', u1_id, 'u2', u2_id);
        eCfg.nomesEntradas      = {'u1', 'u2'};
        eCfg.maxDelay           = cfg.maxDelay;
        eCfg.maxFatoresPorTermo = cfg.maxFatoresPorTermo;
        eCfg.popSize            = cfg.popSize;
        eCfg.nGeracoes          = cfg.nGeracoes;
        eCfg.verbose            = false;

        [melhorModelo, melhorTheta, ~] = evoluir(eCfg);

        mseId  = scoreOsa(melhorTheta, melhorModelo.compile(), eCfg.vars, melhorModelo.maiorAtraso());
        vars_val = struct('y', y_val, 'u1', u1_val, 'u2', u2_val);
        mseVal = scoreOsa(melhorTheta, melhorModelo.compile(), vars_val, melhorModelo.maiorAtraso());

        maxLag = melhorModelo.maiorAtraso();
        y0     = y_id(max(1, end - maxLag + 1) : end);
        y_fr   = melhorModelo.simularFreeRun(melhorTheta, y0, struct('u1', u1_val, 'u2', u2_val));
        y_sim  = y_fr(numel(y0)+1 : end);
        rmseFr = sqrt(mean((y_val - y_sim).^2));

        % Verificar que o modelo usa os nomes corretos u1/u2
        termos = melhorModelo.compile();
        usaU1 = any(cellfun(@(t) ~isempty(strfind(t, 'u1')), termos));
        usaU2 = any(cellfun(@(t) ~isempty(strfind(t, 'u2')), termos));

        rmseOsaVals(si) = sqrt(mseVal);
        linhas{si} = struct('semente', semente, ...
            'rmseOsaId', sqrt(mseId), 'rmseOsaVal', sqrt(mseVal), ...
            'rmseFreeRunVal', rmseFr, 'numTermos', melhorModelo.numTermos(), ...
            'usaU1', usaU1, 'usaU2', usaU2, 'modelo', melhorModelo.toString());

        fprintf('seed %d | OSA-RMSE id=%.4g val=%.4g | FR-RMSE=%.4g | u1=%d u2=%d | %s\n', ...
            semente, sqrt(mseId), sqrt(mseVal), rmseFr, usaU1, usaU2, melhorModelo.toString());
    end

    nPassou = sum(rmseOsaVals < 0.05);
    fprintf('\n--- Sumario ---\n');
    fprintf('OSA-RMSE val: media=%.4g  std=%.4g\n', mean(rmseOsaVals), std(rmseOsaVals));
    fprintf('Estrutura verdadeira: %s\n', estruturaRef);
    fprintf('Threshold OSA-RMSE val < 0.05: %d/%d seeds aprovaram\n', nPassou, cfg.nSeeds);

    resultado = struct('config', cfg, 'resultados', {linhas}, ...
        'rmseOsaValMedia', mean(rmseOsaVals), 'nSeedsPassaram', nPassou);

    if cfg.salvarJson
        salvarBenchJson('miso', resultado);
    end
end

function v = campo(s, nome, default)
    if isfield(s, nome), v = s.(nome); else, v = default; end
end
