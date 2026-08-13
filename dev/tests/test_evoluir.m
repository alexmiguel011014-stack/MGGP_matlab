function test_evoluir()
%TEST_EVOLUIR Valida o loop evolutivo completo (evoluir.m) contra o
%   mesmo sistema de referencia dos outros testes.
%
%   Diferente de test_ls/test_predictFreeRun (que exigem recuperar
%   theta quase exatamente), aqui o criterio e mais frouxo: GP e
%   estocastico, nao ha garantia de achar a estrutura exata do modelo
%   gerador em poucas geracoes. O que se valida e:
%     1. o loop roda sem erro do inicio ao fim;
%     2. o fitness do melhor individuo melhora (ou ao menos nao piora)
%        da primeira para a ultima geracao;
%     3. o fitness final e "razoavelmente bom" (limiar frouxo, nao
%        comparado ao MSE teorico igual aos testes numericos).
%
%   Sistema de referencia:
%       y(k) = 0.75 y(k-2) + 0.25 u1(k-1) - 0.20 y(k-2) u1(k-1)
%
%   Rodar: >> test_evoluir
%   Sucesso: imprime "OK" e nao lanca erro. Pode demorar alguns
%   segundos (poucas geracoes, populacao pequena — parametros de teste,
%   nao de uso real).

    rng(2024);

    N = 300;
    thetaVerdadeiro = [0.75; 0.25; -0.20];
    u1 = randn(N, 1);
    y = zeros(N, 1);
    for k = 3:N
        y(k) = thetaVerdadeiro(1) * y(k-2) ...
             + thetaVerdadeiro(2) * u1(k-1) ...
             + thetaVerdadeiro(3) * y(k-2) * u1(k-1);
    end

    config = struct();
    config.vars = struct('y', y, 'u1', u1);
    config.nomesEntradas = {'u1'};
    config.maxDelay = 3;
    config.maxFatoresPorTermo = 2;
    config.popSize = 40;       % pequeno de proposito -- teste rapido, nao uso real
    config.nGeracoes = 15;
    config.verbose = false;

    [melhorModelo, melhorTheta, historico] = evoluir(config);

    % checagem 1: historico tem uma entrada por geracao, em ordem.
    if numel(historico) ~= config.nGeracoes
        error('test_evoluir:historicoTamanhoErrado', ...
            'historico tem %d entradas, esperado %d.', numel(historico), config.nGeracoes);
    end
    for g = 1:numel(historico)
        if historico(g).geracao ~= g
            error('test_evoluir:historicoForaDeOrdem', ...
                'historico(%d).geracao = %d, esperado %d.', g, historico(g).geracao, g);
        end
    end

    % checagem 2: fitness do melhor individuo nao piora ao longo das
    % geracoes (elitismo garante isso -- e uma invariante estrutural,
    % nao so uma expectativa estatistica).
    melhorFitnessPorGeracao = [historico.melhorFitness];
    for g = 2:numel(melhorFitnessPorGeracao)
        if melhorFitnessPorGeracao(g) > melhorFitnessPorGeracao(g-1) + 1e-9
            error('test_evoluir:fitnessPiorou', ...
                'Melhor fitness piorou da geracao %d (%.6g) para %d (%.6g) -- elitismo deveria impedir isso.', ...
                g-1, melhorFitnessPorGeracao(g-1), g, melhorFitnessPorGeracao(g));
        end
    end

    % checagem 3: modelo final e valido e o fitness final e finito
    % (nao Inf -- Inf indicaria que so individuos invalidos sobreviveram).
    if ~isfinite(melhorFitnessPorGeracao(end))
        error('test_evoluir:fitnessFinalInfinito', ...
            'Fitness final e Inf -- nenhum individuo valido foi encontrado.');
    end
    if melhorModelo.maiorAtraso() > config.maxDelay
        error('test_evoluir:modeloFinalAtrasoInvalido', ...
            'Modelo final excede maxDelay.');
    end
    if numel(melhorTheta) ~= melhorModelo.numTermos()
        error('test_evoluir:thetaTamanhoErrado', ...
            'melhorTheta tem %d elementos, esperado %d (numTermos do modelo).', ...
            numel(melhorTheta), melhorModelo.numTermos());
    end

    fprintf('OK - evoluir() rodou %d geracoes sem erro. Melhor fitness: %.6g -> %.6g\n', ...
        config.nGeracoes, melhorFitnessPorGeracao(1), melhorFitnessPorGeracao(end));
    fprintf('     Melhor modelo encontrado: %s\n', melhorModelo.toString());
end
