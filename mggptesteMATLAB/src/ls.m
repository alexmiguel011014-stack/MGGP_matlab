function [theta, P, yAlinhado] = ls(vars, terms, maxDelay)
%LS Estima os parametros de um modelo NARX (SISO ou MISO) por minimos quadrados.
%
%   THETA = LS(vars, terms, maxDelay) monta a matriz de regressores via
%   MAKEREGRESSORS e resolve theta = (P'P)^-1 P'y (via mldivide, mais
%   estavel numericamente que a inversa explicita).
%
%   Espelha mggpElement.ls da biblioteca Python original (CastroHc/MGGP).
%
%   ENTRADAS
%     vars, terms, maxDelay - mesmos argumentos de MAKEREGRESSORS. vars
%         deve conter o campo 'y' (saida) e um campo por variavel de
%         entrada usada em TERMS.
%
%   SAIDAS
%     theta     - vetor coluna (numel(terms)+1)x1: theta(1) e o bias
%                 (coluna de ones em P), theta(2:end) sao os coeficientes
%                 dos termos em TERMS. Alinhado com MAKEREGRESSORS e
%                 PREDICTFREERUN.
%     P         - matriz de regressores usada (retornada para inspecao/
%                 reuso, evita remontar se o chamador precisar dela).
%     yAlinhado - y recortado na mesma janela de amostras validas de P,
%                 pronto para comparar com P*theta.
%
%   Ver tambem: MAKEREGRESSORS, PREDICTFREERUN

    if nargin < 3
        maxDelay = Inf;
    end

    P = makeRegressors(vars, terms, maxDelay);

    y = vars.y(:);
    numAmostrasValidas = size(P, 1);
    yAlinhado = y((end - numAmostrasValidas + 1):end);

    theta = P \ yAlinhado;
end
