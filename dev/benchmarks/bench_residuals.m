function bench_residuals(resultado_siso)
%BENCH_RESIDUALS Analise de residuos do modelo identificado por bench_siso.
%
%   BENCH_RESIDUALS(resultado_siso) — usa o resultado retornado por bench_siso().
%   BENCH_RESIDUALS()               — gera os dados internamente (seed 42).
%
%   Metricas:
%     mean(e)                   — deve ser proximo de zero
%     corr(e(t), e(t-1))        — autocorrelacao lag-1 (< 0.05 = residuos brancos)
%     corr(e(t), u1(t-maxLag))  — correlacao cruzada com entrada (< 0.05 = residuos
%                                 independentes das entradas passadas)
%
%   Salva resultados em dev/benchmarks/results/residuals_siso.json.

    N      = 1000;
    N_id   = round(0.7 * N);
    maxDelay = 3;
    thetaVerdadeiro = [0.75; 0.25; -0.20];

    if nargin < 1
        % Gerar dados do seed 42 e rodar identificacao rapida
        rng(42);
        u1 = randn(N, 1);
        y  = zeros(N, 1);
        for k = 3:N
            y(k) = thetaVerdadeiro(1)*y(k-2) + thetaVerdadeiro(2)*u1(k-1) ...
                 + thetaVerdadeiro(3)*y(k-2)*u1(k-1);
        end

        cfg = struct('vars', struct('y', y(1:N_id), 'u1', u1(1:N_id)), ...
            'nomesEntradas', {{'u1'}}, 'maxDelay', maxDelay, ...
            'maxFatoresPorTermo', 2, 'popSize', 100, 'nGeracoes', 50, 'verbose', false);
        [melhorModelo, melhorTheta, ~] = evoluir(cfg);

        y_val  = y(N_id+1:end);
        u1_val = u1(N_id+1:end);
        vars_val = struct('y', y_val, 'u1', u1_val);
    else
        % Pegar o melhor seed do resultado de bench_siso
        rmses = cellfun(@(r) r.rmseOsaVal, resultado_siso.resultados);
        [~, iMelhor] = min(rmses);
        fprintf('Usando seed %d (melhor OSA-RMSE val = %.4g)\n', ...
            resultado_siso.resultados{iMelhor}.semente, rmses(iMelhor));

        % Recriar dados desse seed para ter acesso a y_val e u1_val
        semente = resultado_siso.resultados{iMelhor}.semente;
        rng(semente);
        u1 = randn(N, 1);
        y  = zeros(N, 1);
        for k = 3:N
            y(k) = thetaVerdadeiro(1)*y(k-2) + thetaVerdadeiro(2)*u1(k-1) ...
                 + thetaVerdadeiro(3)*y(k-2)*u1(k-1);
        end

        cfg = struct('vars', struct('y', y(1:N_id), 'u1', u1(1:N_id)), ...
            'nomesEntradas', {{'u1'}}, 'maxDelay', maxDelay, ...
            'maxFatoresPorTermo', 2, 'popSize', 100, 'nGeracoes', 50, 'verbose', false);
        [melhorModelo, melhorTheta, ~] = evoluir(cfg);

        y_val  = y(N_id+1:end);
        u1_val = u1(N_id+1:end);
        vars_val = struct('y', y_val, 'u1', u1_val);
    end

    % Calcular predicao OSA e residuos
    P = makeRegressors(vars_val, melhorModelo.compile(), melhorModelo.maiorAtraso());
    nVal = size(P, 1);
    y_osa = P * melhorTheta;
    e = y_val(end - nVal + 1 : end) - y_osa;

    % Metricas de residuos
    media_e     = mean(e);
    autocorr_e  = corr(e(2:end), e(1:end-1));
    xcorr_eu    = corr(e(maxDelay+1:end), u1_val(1:end-maxDelay));

    fprintf('=== Analise de residuos ===\n');
    fprintf('  mean(e)                   = %.4g  (esperado: ~0)\n', media_e);
    fprintf('  corr(e[t], e[t-1])        = %.4g  (< 0.05 = brancos)\n', autocorr_e);
    fprintf('  corr(e[t], u1[t-maxLag])  = %.4g  (< 0.05 = independentes)\n', xcorr_eu);
    fprintf('  Modelo: %s\n', melhorModelo.toString());

    % Salvar JSON
    metrics = struct('mean_e', media_e, 'autocorr_lag1', autocorr_e, ...
        'xcorr_com_entrada', xcorr_eu, 'modelo', melhorModelo.toString());
    salvarBenchJson('residuals_siso', struct('metrics', metrics));
end
