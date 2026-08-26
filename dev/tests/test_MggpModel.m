function test_MggpModel()
%TEST_MGGPMODEL Valida MggpTerm/MggpModel contra o mesmo sistema de
%   referencia dos outros testes, construido via estrutura (nao string
%   escrita a mao) e comparado ao resultado ja validado em test_ls.m.
%
%   Sistema de referencia:
%       y(k) = 0.75 y(k-2) + 0.25 u(k-1) - 0.20 y(k-2) u(k-1)
%
%   Rodar: >> test_MggpModel
%   Sucesso: imprime "OK" e nao lanca erro.

    % --- construcao via estrutura, nao string ---
    termoY2   = MggpTerm.var('y', 2);
    termoU1   = MggpTerm.var('u', 1);
    termoY2U1 = MggpTerm.produto(MggpTerm.var('y', 2), MggpTerm.var('u', 1));

    modelo = MggpModel([termoY2, termoU1, termoY2U1]);

    % checagem 1: compile() gera exatamente a mesma sintaxe que
    % makeRegressors/ls ja aceitam (mesmas strings usadas em test_ls.m).
    esperado = {'q2(y)', 'q1(u)', 'q2(y)*q1(u)'};
    obtido = modelo.compile();
    if ~isequal(obtido, esperado)
        error('test_MggpModel:compileDivergente', ...
            'compile() nao bateu.\nesperado: %s\nobtido:   %s', ...
            strjoin(esperado, ', '), strjoin(obtido, ', '));
    end

    % checagem 2: maiorAtraso() bate com o esperado (2, do termo q2(y)).
    if modelo.maiorAtraso() ~= 2
        error('test_MggpModel:maiorAtrasoErrado', ...
            'maiorAtraso() retornou %d, esperado 2.', modelo.maiorAtraso());
    end

    % checagem 3: numTermos() bate.
    if modelo.numTermos() ~= 3
        error('test_MggpModel:numTermosErrado', ...
            'numTermos() retornou %d, esperado 3.', modelo.numTermos());
    end

    % checagem 4: round-trip completo via metodos da classe
    % (estimarTheta + simularFreeRun), mesma tolerancia dos testes
    % anteriores.
    rng(42);
    N = 500;
    % bias=0 explícito (theta tem nTerms+1 elementos pós G4-1)
    thetaVerdadeiro = [0; 0.75; 0.25; -0.20];

    u = randn(N, 1);
    y0 = zeros(2, 1);

    y = modelo.simularFreeRun(thetaVerdadeiro, y0, struct('u', u));
    ySimulado = y(3:end); % remove prefixo de y0 (2 amostras)

    thetaReestimado = modelo.estimarTheta(struct('y', ySimulado, 'u', u));
    erro = abs(thetaReestimado - thetaVerdadeiro);
    tolerancia = 1e-8;

    if any(erro > tolerancia)
        error('test_MggpModel:roundTripFalhou', ...
            'theta reestimado via MggpModel nao bateu (erro max: %.2e).', max(erro));
    end

    % checagem 5: termo duplicado deve lancar erro.
    duplicataLancouErro = false;
    try
        MggpModel([termoY2, termoY2]); %#ok<NASGU>
    catch err
        if strcmp(err.identifier, 'MggpModel:termosDuplicados')
            duplicataLancouErro = true;
        else
            rethrow(err);
        end
    end
    if ~duplicataLancouErro
        error('test_MggpModel:duplicataNaoDetectada', ...
            'MggpModel deveria rejeitar termos duplicados.');
    end

    fprintf('OK - MggpTerm/MggpModel validados (compile, atraso, round-trip, duplicata)\n');
end
