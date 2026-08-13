function mse = scoreOsa(theta, terms, vars, maxDelay)
%SCOREOSA Erro quadratico medio da predicao um-passo-a-frente (OSA).
%
%   mse = SCOREOSA(theta, terms, vars, maxDelay) calcula o MSE entre a
%   saida medida (vars.y) e a predicao um-passo-a-frente do modelo — ou
%   seja, P*theta usando SEMPRE os regressores construidos a partir dos
%   dados medidos (nunca saida simulada), diferente de PREDICTFREERUN.
%
%   Espelha mggpElement.score_osa da biblioteca Python original
%   (CastroHc/MGGP) — e a funcao de fitness usada no exemplo completo
%   de evolucao do README original (mais estavel numericamente que
%   erro free-run para guiar o motor de GP: um individuo ruim nao pode
%   fazer a predicao "explodir" ao longo do tempo, porque cada passo
%   parte sempre de dado real, nao do erro acumulado do passo anterior).
%
%   ENTRADAS
%     theta    - vetor coluna, parametros do modelo (ver LS).
%     terms    - cell array de strings, mesmo formato de MAKEREGRESSORS.
%     vars     - struct de series (campo 'y' obrigatorio + entradas),
%                mesmo formato de MAKEREGRESSORS/LS.
%     maxDelay - repassado para MAKEREGRESSORS (ver la).
%
%   SAIDA
%     mse - escalar, erro quadratico medio da predicao um-passo-a-frente.
%
%   Ver tambem: MAKEREGRESSORS, LS, PREDICTFREERUN

    if nargin < 4
        maxDelay = Inf;
    end

    P = makeRegressors(vars, terms, maxDelay);
    theta = theta(:);

    y = vars.y(:);
    numAmostrasValidas = size(P, 1);
    yAlinhado = y((end - numAmostrasValidas + 1):end);

    predicao = P * theta;
    residuo = yAlinhado - predicao;
    mse = mean(residuo.^2);
end
