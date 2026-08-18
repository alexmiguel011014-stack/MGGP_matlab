function resultado = bench_nsga2(opcoes)
%BENCH_NSGA2 Validacao do loop NSGA-II: fronte de Pareto e comparacao com evoluir.
%
%   resultado = BENCH_NSGA2()        — config padrao
%   resultado = BENCH_NSGA2(opcoes) — struct de overrides
%
%   Checagens:
%     1. Fronte de Pareto e valido (nenhum par e dominado).
%     2. Ponto de menor erro no fronte esta dentro de 10% do melhor
%        encontrado por evoluir (mono-objetivo) no mesmo dataset/seed.
%     3. Ponto de menor complexidade tem <= 2 termos e fitness finito.
%     4. Historico tem uma entrada por geracao, em ordem.
%
%   Salva resultado em dev/benchmarks/results/nsga2_<timestamp>.json.

    if nargin < 1, opcoes = struct(); end

    cfg.popSize           = campo(opcoes, 'popSize',           80);
    cfg.nGeracoes         = campo(opcoes, 'nGeracoes',         30);
    cfg.N                 = campo(opcoes, 'N',                 700);
    cfg.maxDelay          = campo(opcoes, 'maxDelay',          3);
    cfg.maxFatoresPorTermo = campo(opcoes, 'maxFatoresPorTermo', 2);
    cfg.salvarJson        = campo(opcoes, 'salvarJson',        true);

    thetaVerdadeiro = [0.75; 0.25; -0.20];
    N_id = round(0.7 * cfg.N);

    rng(42);
    u1 = randn(cfg.N, 1);
    y  = zeros(cfg.N, 1);
    for k = 3:cfg.N
        y(k) = thetaVerdadeiro(1)*y(k-2) + thetaVerdadeiro(2)*u1(k-1) ...
             + thetaVerdadeiro(3)*y(k-2)*u1(k-1);
    end

    vars_id = struct('y', y(1:N_id), 'u1', u1(1:N_id));

    % Config compartilhada
    cfgEvol = struct('vars', vars_id, 'nomesEntradas', {{'u1'}}, ...
        'maxDelay', cfg.maxDelay, 'maxFatoresPorTermo', cfg.maxFatoresPorTermo, ...
        'popSize', cfg.popSize, 'nGeracoes', cfg.nGeracoes, 'verbose', false);

    fprintf('=== bench_nsga2 | popSize=%d nGeracoes=%d ===\n', cfg.popSize, cfg.nGeracoes);

    % Rodar NSGA-II
    rng(42);
    [frontePareto, objFronte, historico] = evoluirNsga2(cfgEvol);

    % Checagem 1: historico em ordem
    ok_historico = true;
    for g = 1:numel(historico)
        if historico(g).geracao ~= g, ok_historico = false; break; end
    end
    fprintf('Historico em ordem (%d geracoes): %s\n', numel(historico), tf(ok_historico));

    % Checagem 2: fronte nao-dominado
    nF = numel(frontePareto);
    ok_pareto = true;
    for i = 1:nF
        for j = i+1:nF
            if domina(objFronte(i,:), objFronte(j,:)) || domina(objFronte(j,:), objFronte(i,:))
                ok_pareto = false;
                fprintf('  FALHA: par (%d,%d) e dominado!\n', i, j);
            end
        end
    end
    fprintf('Fronte nao-dominado (%d pontos): %s\n', nF, tf(ok_pareto));

    % Checagem 3: melhor erro do fronte vs evoluir mono-objetivo
    rng(42);
    [~, thetaMono, ~] = evoluir(cfgEvol);
    cfgEvol.verbose = false;
    [melhorMono, thetaMono, ~] = evoluir(cfgEvol);
    erroMono = sqrt(scoreOsa(thetaMono, melhorMono.compile(), vars_id, melhorMono.maiorAtraso()));
    erroFronteMin = sqrt(min(objFronte(:,1)));
    ratio = erroFronteMin / erroMono;
    ok_qualidade = ratio <= 1.10;
    fprintf('Menor erro no fronte: %.4g | evoluir mono-obj: %.4g | ratio=%.3f: %s\n', ...
        erroFronteMin, erroMono, ratio, tf(ok_qualidade));

    % Checagem 4: ponto de menor complexidade
    [~, iMin] = min(objFronte(:,2));
    nTermosMin = objFronte(iMin, 2);
    erroMin    = objFronte(iMin, 1);
    ok_simples = (nTermosMin <= 2) && isfinite(erroMin);
    fprintf('Ponto mais simples: %g termos, erro=%.4g: %s\n', nTermosMin, erroMin, tf(ok_simples));

    % Imprimir fronte
    fprintf('\nFronte de Pareto (%d pontos):\n', nF);
    fprintf('  %-12s  %-10s  modelo\n', 'OSA-RMSE', 'nTermos');
    for i = 1:nF
        fprintf('  %-12.4g  %-10g  %s\n', sqrt(objFronte(i,1)), objFronte(i,2), frontePareto(i).toString());
    end

    resultado = struct('nFronte', nF, 'erroFronteMin', erroFronteMin, ...
        'erroMono', erroMono, 'ratioVsMono', ratio, 'nTermosMin', nTermosMin, ...
        'okPareto', ok_pareto, 'okQualidade', ok_qualidade, 'okSimples', ok_simples);

    if cfg.salvarJson
        salvarBenchJson('nsga2', resultado);
    end
end

function d = domina(a, b)
    d = all(a <= b) && any(a < b);
end

function s = tf(v)
    if v, s = 'OK'; else, s = 'FALHOU'; end
end

function v = campo(s, nome, default)
    if isfield(s, nome), v = s.(nome); else, v = default; end
end
