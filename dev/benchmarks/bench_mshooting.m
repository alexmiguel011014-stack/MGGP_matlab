%BENCH_MSHOOTING Compara fitness OSA vs MShooting no sistema SISO de referencia.
%
%   Roda evolucao identica (mesmo seed, mesmos parametros) duas vezes:
%   uma com tipoFitness='osa' e outra com tipoFitness='mShooting'.
%   Compara OSA-RMSE e free-run RMSE na particao de validacao.
%
%   Uso:
%     cd('D:\ProjetosPessoais\MGGP_Vmatlab')
%     bench_mshooting

setup;

SEEDS   = [42, 43, 44];
N       = 1000;
SPLIT   = 0.7;
BASE_CONFIG = struct( ...
    'nomesEntradas',    {{'u1'}}, ...
    'maxDelay',         3, ...
    'maxFatoresPorTermo', 2, ...
    'popSize',          60, ...
    'nGeracoes',        20, ...
    'verbose',          false);

fprintf('=== bench_mshooting: OSA vs MShooting ===\n\n');

resultados = struct('seed', {}, 'tipo', {}, ...
    'osaRmseVal', {}, 'frRmseVal', {}, 'wallTime', {});

for tipo = {'osa', 'mShooting'}
    tipoStr = tipo{1};
    fprintf('--- tipoFitness = ''%s'' ---\n', tipoStr);

    for s = 1:numel(SEEDS)
        seed = SEEDS(s);
        rng(seed);

        % Gerar dados
        u1 = randn(N, 1);
        y  = zeros(N, 1);
        for k = 3:N
            y(k) = 0.75*y(k-2) + 0.25*u1(k-1) - 0.20*y(k-2)*u1(k-1);
        end

        nId  = round(N * SPLIT);
        vars_id  = struct('y', y(1:nId),       'u1', u1(1:nId));
        vars_val = struct('y', y(nId+1:end),   'u1', u1(nId+1:end));

        config = BASE_CONFIG;
        config.vars         = vars_id;
        config.tipoFitness  = tipoStr;

        t0 = tic;
        [melhorModelo, melhorTheta] = evoluir(config);
        wallTime = toc(t0);

        terms = melhorModelo.compile();
        maxD  = melhorModelo.maiorAtraso();

        % OSA-RMSE validacao
        osaVal = sqrt(scoreOsa(melhorTheta, terms, vars_val, maxD));

        % Free-run RMSE validacao
        y0Val    = vars_val.y(1:maxD);
        inpVal   = struct('u1', vars_val.u1(maxD+1:end));
        yFr      = predictFreeRun(melhorTheta, terms, y0Val, inpVal);
        yFrPred  = yFr(maxD+1:end);
        yFrTrue  = vars_val.y(maxD+1:end);
        frVal    = sqrt(mean((yFrTrue - yFrPred).^2));

        fprintf('  seed=%d | OSA-RMSE(val)=%.5f | FR-RMSE(val)=%.5f | t=%.1fs\n', ...
            seed, osaVal, frVal, wallTime);

        resultados(end+1) = struct('seed', seed, 'tipo', tipoStr, ...
            'osaRmseVal', osaVal, 'frRmseVal', frVal, 'wallTime', wallTime); %#ok<AGROW>
    end
    fprintf('\n');
end

% Resumo comparativo
fprintf('=== Resumo (media de %d seeds) ===\n', numel(SEEDS));
fprintf('%-12s | OSA-RMSE(val) | FR-RMSE(val) | Tempo(s)\n', 'Fitness');
fprintf('%s\n', repmat('-', 1, 55));
for tipo = {'osa', 'mShooting'}
    tipoStr = tipo{1};
    mask = strcmp({resultados.tipo}, tipoStr);
    r = resultados(mask);
    fprintf('%-12s | %13.5f | %12.5f | %8.1f\n', tipoStr, ...
        mean([r.osaRmseVal]), mean([r.frRmseVal]), mean([r.wallTime]));
end

% Verificar limiar: FR-RMSE(mShooting) <= FR-RMSE(osa) * 1.5
mask_osa = strcmp({resultados.tipo}, 'osa');
mask_ms  = strcmp({resultados.tipo}, 'mShooting');
frOsa = mean([resultados(mask_osa).frRmseVal]);
frMs  = mean([resultados(mask_ms).frRmseVal]);
limiar = frOsa * 1.5;
fprintf('\nLimiar: FR-RMSE(mShooting) <= FR-RMSE(osa)*1.5 = %.5f\n', limiar);
if frMs <= limiar
    fprintf('PASS: FR-RMSE(mShooting)=%.5f <= %.5f\n', frMs, limiar);
else
    fprintf('WARN: FR-RMSE(mShooting)=%.5f > %.5f\n', frMs, limiar);
end

% Salvar resultados
salvarBenchJson('mshooting', struct( ...
    'resultados', resultados, ...
    'seeds', SEEDS, ...
    'frRmseOsa', frOsa, ...
    'frRmseMShooting', frMs, ...
    'passou', frMs <= limiar));
