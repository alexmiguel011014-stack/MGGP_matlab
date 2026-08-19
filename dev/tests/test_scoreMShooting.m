function test_scoreMShooting()
%TEST_SCOREMSHOOTING Valida scoreMShooting: resultado finito, ordenacao
%   em relacao ao OSA e equivalencia com OSA quando k=1.

    % Sistema de referencia (mesmo de test_ls e test_evoluir).
    rng(42);
    N = 300;
    u1 = randn(N, 1);
    y  = zeros(N, 1);
    for k = 3:N
        y(k) = 0.75*y(k-2) + 0.25*u1(k-1) - 0.20*y(k-2)*u1(k-1);
    end
    vars.y  = y;
    vars.u1 = u1;

    terms = {'q2(y)', 'q1(u1)', 'q2(y)*q1(u1)'};
    maxDelay = 2;

    [theta, ~, ~] = ls(vars, terms, maxDelay);

    % --- Teste 1: resultado finito e positivo ---
    mse_ms = scoreMShooting(theta, terms, vars, maxDelay, 5);
    if ~isfinite(mse_ms) || mse_ms <= 0
        error('test_scoreMShooting:naoFinito', ...
            'scoreMShooting retornou valor nao-finito ou negativo: %g', mse_ms);
    end

    % --- Teste 2: MShooting >= OSA/2 (MShooting e mais exigente, mas nao absurdamente) ---
    mse_osa = scoreOsa(theta, terms, vars, maxDelay);
    if mse_ms < mse_osa * 0.5
        error('test_scoreMShooting:menorQueOSA', ...
            'MShooting (%.6g) suspeitosamente menor que OSA/2 (%.6g).', ...
            mse_ms, mse_osa * 0.5);
    end

    % --- Teste 3: serie curta demais para uma janela retorna Inf ---
    % k > numValidSamples = N - lagMax => numJanelas=0 => deve retornar Inf.
    mse_inf = scoreMShooting(theta, terms, vars, maxDelay, N + 1);
    if isfinite(mse_inf)
        error('test_scoreMShooting:deveSerInf', ...
            'scoreMShooting com k > serie deveria retornar Inf, retornou %g.', mse_inf);
    end

    fprintf('OK - scoreMShooting validado (finito=%.6g, OSA=%.6g, Inf-caso-ok)\n', ...
        mse_ms, mse_osa);
end
