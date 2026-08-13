function test_evoluirNsga2()
%TEST_EVOLUIRNSGA2 Valida evoluirNsga2 contra o mesmo sistema de
%   referencia dos outros testes de evolucao.
%
%   Assim como test_evoluir.m, o criterio aqui e estrutural, nao de
%   exatidao (GP e estocastico): o loop roda sem erro, a fronteira de
%   Pareto final e realmente nao-dominada (nenhum membro domina outro
%   membro do mesmo fronte — testa a corretude do proprio algoritmo,
%   nao so que ele "roda"), e o fronte cobre um trade-off real
%   (contém pelo menos 2 modelos com numero de termos diferentes, ou
%   um unico modelo se a busca convergiu — ambos sao resultados
%   validos, mas o teste avisa qual ocorreu).
%
%   Sistema de referencia:
%       y(k) = 0.75 y(k-2) + 0.25 u1(k-1) - 0.20 y(k-2) u1(k-1)
%
%   Rodar: >> test_evoluirNsga2
%   Sucesso: imprime "OK" e nao lanca erro.

    rng(4242);

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
    config.popSize = 40;
    config.nGeracoes = 15;
    config.verbose = false;

    [frontePareto, objetivosFrontePareto, historico] = evoluirNsga2(config);

    % checagem 1: fronte nao vazio.
    if isempty(frontePareto)
        error('test_evoluirNsga2:fronteVazio', ...
            'A fronteira de Pareto final nao pode ser vazia.');
    end

    % checagem 2: historico tem uma entrada por geracao, em ordem.
    if numel(historico) ~= config.nGeracoes
        error('test_evoluirNsga2:historicoTamanhoErrado', ...
            'historico tem %d entradas, esperado %d.', numel(historico), config.nGeracoes);
    end

    % checagem 3 (a mais importante): nenhum membro do fronte final
    % domina outro membro do mesmo fronte -- testa a corretude do
    % proprio NSGA-II, nao so que ele terminou sem erro.
    n = size(objetivosFrontePareto, 1);
    for i = 1:n
        for j = 1:n
            if i == j
                continue;
            end
            if dominanciaParento(objetivosFrontePareto(i, :), objetivosFrontePareto(j, :))
                error('test_evoluirNsga2:fronteNaoEhParentoValido', ...
                    ['Individuo %d (objetivos=[%.6g, %d]) domina o individuo %d ' ...
                     '(objetivos=[%.6g, %d]) -- isso nao deveria acontecer dentro ' ...
                     'da mesma fronteira de Pareto final.'], ...
                    i, objetivosFrontePareto(i,1), objetivosFrontePareto(i,2), ...
                    j, objetivosFrontePareto(j,1), objetivosFrontePareto(j,2));
            end
        end
    end

    % checagem 4: todo modelo no fronte e estruturalmente valido.
    for i = 1:numel(frontePareto)
        if frontePareto(i).maiorAtraso() > config.maxDelay
            error('test_evoluirNsga2:modeloFronteAtrasoInvalido', ...
                'Modelo %d do fronte excede maxDelay.', i);
        end
        if frontePareto(i).numTermos() ~= objetivosFrontePareto(i, 2)
            error('test_evoluirNsga2:numTermosInconsistente', ...
                'Modelo %d: numTermos() = %d, mas objetivo registrado = %d.', ...
                i, frontePareto(i).numTermos(), objetivosFrontePareto(i, 2));
        end
    end

    numComplexidadesDistintas = numel(unique(objetivosFrontePareto(:, 2)));
    fprintf('OK - evoluirNsga2() rodou %d geracoes. Fronte final: %d modelos, %d niveis de complexidade distintos.\n', ...
        config.nGeracoes, numel(frontePareto), numComplexidadesDistintas);
    if numComplexidadesDistintas == 1
        fprintf('     (fronte convergiu para uma unica complexidade -- resultado valido, so nao ilustra o trade-off)\n');
    end
end
