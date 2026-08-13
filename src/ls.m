function [theta, P, yAlinhado] = ls(y, u, terms, maxDelay)
%LS Estima os parametros de um modelo NARX por minimos quadrados.
%
%   THETA = LS(y, u, terms, maxDelay) monta a matriz de regressores via
%   MAKEREGRESSORS e resolve theta = (P'P)^-1 P'y (via mldivide, mais
%   estavel numericamente que a inversa explicita).
%
%   Espelha mggpElement.ls da biblioteca Python original (CastroHc/MGGP).
%
%   ENTRADAS
%     y, u, terms, maxDelay - mesmos argumentos de MAKEREGRESSORS.
%
%   SAIDAS
%     theta     - vetor coluna numel(terms)x1 com os parametros estimados.
%     P         - matriz de regressores usada (retornada para inspecao/
%                 reuso, evita remontar se o chamador precisar dela).
%     yAlinhado - y recortado na mesma janela de amostras validas de P,
%                 pronto para comparar com P*theta.
%
%   Ver tambem: MAKEREGRESSORS, PREDICTFREERUN

    if nargin < 4
        maxDelay = Inf;
    end

    P = makeRegressors(y, u, terms, maxDelay);

    y = y(:);
    numAmostrasValidas = size(P, 1);
    yAlinhado = y((end - numAmostrasValidas + 1):end);

    theta = P \ yAlinhado;
end
