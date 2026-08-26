function test_predictFreeRun()
%TEST_PREDICTFREERUN Valida predictFreeRun via round-trip com ls.
%
%   Round-trip: simula um sistema conhecido com predictFreeRun usando
%   theta_verdadeiro, depois reestima theta a partir da saida simulada
%   usando ls. Se as duas funcoes forem consistentes entre si, o theta
%   reestimado deve bater com o original — sem depender de nenhuma
%   simulacao "manual" auxiliar (diferente de test_ls.m, que gera dados
%   de forma independente; aqui o objetivo e testar as duas funcoes
%   uma contra a outra).
%
%   Mesmo sistema de referencia do README original:
%       y(k) = 0.75 y(k-2) + 0.25 u(k-1) - 0.20 y(k-2) u(k-1)
%
%   Rodar: >> test_predictFreeRun
%   Sucesso: imprime "OK" e nao lanca erro.

    rng(7);

    N = 500;
    % bias=0 explícito (theta agora tem nTerms+1 elementos pós G4-1)
    thetaVerdadeiro = [0; 0.75; 0.25; -0.20];
    terms = {'q2(y)', 'q1(u)', 'q2(y)*q1(u)'};

    u = randn(N, 1); % u(1) = instante 0 em diante (ver convencao no cabecalho de predictFreeRun)
    y0 = zeros(2, 1); % duas condicoes iniciais, pois maxLagUsado = 2

    inputs = struct('u', u);
    yComPrefixo = predictFreeRun(thetaVerdadeiro, terms, y0, inputs);

    % checagem 1: causalidade -- as duas primeiras amostras devem ser
    % exatamente y0, sem alteracao pela simulacao.
    if any(yComPrefixo(1:2) ~= y0)
        error('test_predictFreeRun:condicoesIniciaisAlteradas', ...
            'predictFreeRun nao deveria alterar as condicoes iniciais.');
    end

    % remove o prefixo de condicoes iniciais para comparar com a serie
    % "pura" que makeRegressors/ls esperam (mesma convencao de indice
    % absoluto que u ja usa, sem y0 na frente).
    ySimulado = yComPrefixo((numel(y0) + 1):end);

    % checagem 2: round-trip com ls -- reestima theta a partir da saida
    % simulada e confere que bate com o valor usado para gerar os dados.
    vars = struct('y', ySimulado, 'u', u);
    thetaReestimado = ls(vars, terms);
    erro = abs(thetaReestimado - thetaVerdadeiro);
    tolerancia = 1e-8;

    if any(erro > tolerancia)
        error('test_predictFreeRun:roundTripFalhou', ...
            ['theta reestimado (via ls sobre saida de predictFreeRun) ' ...
             'nao bateu.\nesperado: [%.6f, %.6f, %.6f, %.6f]\n' ...
             'obtido:   [%.6f, %.6f, %.6f, %.6f]\nerro max: %.2e'], ...
            thetaVerdadeiro(1), thetaVerdadeiro(2), thetaVerdadeiro(3), thetaVerdadeiro(4), ...
            thetaReestimado(1), thetaReestimado(2), thetaReestimado(3), thetaReestimado(4), ...
            max(erro));
    end

    fprintf('OK - round-trip predictFreeRun -> ls bateu (erro max: %.2e)\n', max(erro));
end
