function test_ls()
%TEST_LS Valida makeRegressors + ls contra um sistema NARX conhecido.
%
%   Sistema de referencia (mesmo exemplo do README da biblioteca Python
%   original, CastroHc/MGGP):
%
%       y(k) = 0.75 y(k-2) + 0.25 u(k-1) - 0.20 y(k-2) u(k-1)
%
%   Gera dados simulando esse sistema com theta conhecido, depois roda
%   LS sobre os mesmos dados e verifica que o theta estimado bate com o
%   theta usado para gerar os dados.
%
%   Rodar: >> test_ls
%   Sucesso: imprime "OK" e nao lanca erro.
%   Falha: lanca erro descrevendo a diferenca encontrada.

    rng(42); % reprodutibilidade

    N = 500;
    % bias=0 explícito: makeRegressors prepend ones, LS retorna (nTerms+1)x1
    thetaVerdadeiro = [0; 0.75; 0.25; -0.20];
    terms = {'q2(y)', 'q1(u)', 'q2(y)*q1(u)'};

    u = randn(N, 1);
    y = zeros(N, 1);

    % Simulacao manual do sistema (free-run), amostra a amostra --
    % gerar os dados de forma independente do proprio makeRegressors,
    % para nao "testar a funcao contra ela mesma".
    % thetaVerdadeiro(1) = bias = 0; indices 2..4 sao os 3 coeficientes.
    for k = 3:N
        y(k) = thetaVerdadeiro(2) * y(k-2) ...
             + thetaVerdadeiro(3) * u(k-1) ...
             + thetaVerdadeiro(4) * y(k-2) * u(k-1);
    end

    vars = struct('y', y, 'u', u);
    thetaEstimado = ls(vars, terms);

    erro = abs(thetaEstimado - thetaVerdadeiro);
    tolerancia = 1e-8; % sem ruido no sistema, deve recuperar quase exato

    if any(erro > tolerancia)
        error('test_ls:falhou', ...
            ['theta estimado nao bateu com o esperado.\n' ...
             'esperado: [%.6f, %.6f, %.6f, %.6f]\n' ...
             'obtido:   [%.6f, %.6f, %.6f, %.6f]\n' ...
             'erro max: %.2e (tolerancia: %.2e)'], ...
            thetaVerdadeiro(1), thetaVerdadeiro(2), thetaVerdadeiro(3), thetaVerdadeiro(4), ...
            thetaEstimado(1), thetaEstimado(2), thetaEstimado(3), thetaEstimado(4), ...
            max(erro), tolerancia);
    end

    fprintf('OK - theta estimado: [%.6f, %.6f, %.6f, %.6f] (esperado: [0, 0.75, 0.25, -0.20])\n', ...
        thetaEstimado(1), thetaEstimado(2), thetaEstimado(3), thetaEstimado(4));
end
