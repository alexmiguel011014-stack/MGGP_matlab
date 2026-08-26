function test_evoluirMimo()
%TEST_EVOLUIRMIMO Testes para evoluirMimo e predictFreeRunMimo.
%
%   Sistema MIMO sintetico desacoplado (2 saidas):
%     y1(k) = 0.7*y1(k-1) + 0.3*u1(k-1)
%     y2(k) = 0.5*y2(k-1) + 0.4*u2(k-1)
%
%   Desacoplado para que o resultado seja deterministico e previsivel.
%   Cada sub-modelo deve encontrar termos q1(y) e q1(u<i>) com RMSE baixo.

    rng(42);
    N = 600;
    u1 = randn(N, 1);
    u2 = randn(N, 1);
    y1 = zeros(N, 1);
    y2 = zeros(N, 1);
    for k = 2:N
        y1(k) = 0.7*y1(k-1) + 0.3*u1(k-1);
        y2(k) = 0.5*y2(k-1) + 0.4*u2(k-1);
    end

    N_id = round(0.7 * N);
    vars = struct('y1', y1(1:N_id), 'y2', y2(1:N_id), ...
                  'u1', u1(1:N_id), 'u2', u2(1:N_id));

    cfg = struct();
    cfg.vars = vars;
    cfg.nomesOutputs  = {'y1', 'y2'};
    cfg.nomesEntradas = {'u1', 'u2'};
    cfg.maxDelay           = 2;
    cfg.maxFatoresPorTermo = 2;
    cfg.popSize            = 60;
    cfg.nGeracoes          = 30;
    cfg.verbose            = false;

    % --- Teste 1: evoluirMimo retorna modelos validos para ambas as saidas ---
    [modelos, thetas, historicos] = evoluirMimo(cfg);

    if numel(modelos) ~= 2
        error('test_evoluirMimo:numModelosErrado', ...
            'Esperado 2 modelos, recebido %d.', numel(modelos));
    end
    for i = 1:2
        if ~isa(modelos{i}, 'MggpModel')
            error('test_evoluirMimo:tipoInvalido', ...
                'modelos{%d} nao e MggpModel.', i);
        end
        if ~isfinite(thetas{i}(1))
            error('test_evoluirMimo:thetaNaoFinito', ...
                'thetas{%d} contem valores nao-finitos.', i);
        end
        if isempty(historicos{i})
            error('test_evoluirMimo:historicoVazio', ...
                'historicos{%d} esta vazio.', i);
        end
    end

    % --- Teste 2: fitness OSA finito e razoavel em ambas as saidas ---
    vars1 = struct('y', y1(1:N_id), 'u1', u1(1:N_id), 'u2', u2(1:N_id), ...
                   'y2', y2(1:N_id));
    vars2 = struct('y', y2(1:N_id), 'u1', u1(1:N_id), 'u2', u2(1:N_id), ...
                   'y1', y1(1:N_id));

    mse1 = scoreOsa(thetas{1}, modelos{1}.compile(), vars1, modelos{1}.maiorAtraso());
    mse2 = scoreOsa(thetas{2}, modelos{2}.compile(), vars2, modelos{2}.maiorAtraso());

    if ~isfinite(mse1) || mse1 > 1.0
        error('test_evoluirMimo:fitness1Alto', ...
            'OSA MSE para y1 muito alto ou nao-finito: %.4g', mse1);
    end
    if ~isfinite(mse2) || mse2 > 1.0
        error('test_evoluirMimo:fitness2Alto', ...
            'OSA MSE para y2 muito alto ou nao-finito: %.4g', mse2);
    end

    % --- Teste 3: predictFreeRunMimo retorna matriz do tamanho correto ---
    maxLag = max(modelos{1}.maiorAtraso(), modelos{2}.maiorAtraso());
    Y0 = [y1(N_id - maxLag + 1 : N_id), y2(N_id - maxLag + 1 : N_id)];

    N_val = N - N_id;
    inputs_val = struct('u1', u1(N_id+1:end), 'u2', u2(N_id+1:end));

    Ys = predictFreeRunMimo(modelos, thetas, Y0, inputs_val, cfg.nomesOutputs);

    esperado = maxLag + N_val;
    if size(Ys, 1) ~= esperado || size(Ys, 2) ~= 2
        error('test_evoluirMimo:tamanhoPredMimo', ...
            'predictFreeRunMimo: esperado [%dx2], recebido [%dx%d].', ...
            esperado, size(Ys, 1), size(Ys, 2));
    end

    % --- Teste 4: RMSE free-run razoavel em validacao ---
    yPred1 = Ys(maxLag+1:end, 1);
    yPred2 = Ys(maxLag+1:end, 2);
    y1_val = y1(N_id+1:end);
    y2_val = y2(N_id+1:end);

    rmse1 = sqrt(mean((y1_val - yPred1).^2));
    rmse2 = sqrt(mean((y2_val - yPred2).^2));

    limiteRmse = 0.5;
    if rmse1 > limiteRmse
        error('test_evoluirMimo:rmse1Alto', ...
            'FR-RMSE para y1 muito alto: %.4g (limite: %.1f)', rmse1, limiteRmse);
    end
    if rmse2 > limiteRmse
        error('test_evoluirMimo:rmse2Alto', ...
            'FR-RMSE para y2 muito alto: %.4g (limite: %.1f)', rmse2, limiteRmse);
    end

    fprintf('OK test_evoluirMimo — y1 OSA-MSE=%.4g FR-RMSE=%.4g | y2 OSA-MSE=%.4g FR-RMSE=%.4g\n', ...
        mse1, rmse1, mse2, rmse2);
end
