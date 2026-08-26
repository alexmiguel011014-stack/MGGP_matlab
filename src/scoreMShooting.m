function mse = scoreMShooting(theta, terms, vars, maxDelay, k)
%SCOREMSHOOTING Erro quadratico medio por simulacao em janelas (MShooting).
%
%   mse = SCOREMSHOOTING(theta, terms, vars, maxDelay, k) divide a serie
%   temporal em janelas nao sobrepostas de k passos e faz simulacao
%   free-run dentro de cada janela — reiniciando com o y real a cada
%   limite de janela. Penaliza modelos instáveis mais que SCOREOSA
%   (que reseta a cada passo) e menos que PREDICTFREERUN sobre a serie
%   inteira.
%
%   Espelha mggp.evaluation com evaluationType='MShooting' da biblioteca
%   Python original (CastroHc/MGGP), generalizado para MISO.
%
%   ENTRADAS
%     theta    - vetor coluna, parametros do modelo (ver LS).
%     terms    - cell array de strings, mesmo formato de MAKEREGRESSORS.
%     vars     - struct de series (campo 'y' + entradas nomeadas),
%                mesmo formato de MAKEREGRESSORS/LS.
%     maxDelay - atraso maximo; define quantas amostras iniciais sao
%                descartadas como condicoes iniciais.
%     k        - tamanho da janela em amostras (default 5, mesmo default
%                da biblioteca Python).
%
%   SAIDA
%     mse - escalar, MSE medio sobre todas as janelas completas.
%           Retorna Inf se a serie for curta demais para uma janela.
%
%   Ver tambem: SCOREOSA, PREDICTFREERUN, MAKEREGRESSORS

    if nargin < 5
        k = 5;
    end

    theta = theta(:);
    y = vars.y(:);
    N = numel(y);

    nomesEntradas = fieldnames(vars);
    nomesEntradas = nomesEntradas(~strcmp(nomesEntradas, 'y'));

    lagMax = maxDelay;

    % Windowing alinhado com a biblioteca Python original:
    % window = lagMax+1 amostras de CI + k amostras de predicao.
    % Janelas comecam no inicio da serie (nao apos lagMax amostras),
    % espelhando miso_MShooting em src/predictors.py (CastroHc/MGGP).
    windowSize = lagMax + 1 + k;
    numJanelas = floor(N / windowSize);

    if numJanelas < 1
        mse = Inf;
        return;
    end

    errosQuad = zeros(numJanelas * k, 1);

    for w = 1:numJanelas
        ini      = (w - 1) * windowSize + 1;
        % CI: lagMax+1 amostras (igual ao Python que usa lagMax+1)
        y0       = y(ini : ini + lagMax);
        winStart = ini + lagMax + 1;
        winEnd   = ini + lagMax + k;

        % Entradas reais para esta janela.
        winInputs = struct();
        for i = 1:numel(nomesEntradas)
            nome = nomesEntradas{i};
            winInputs.(nome) = vars.(nome)(winStart:winEnd);
        end

        % Free-run k passos a partir das condicoes iniciais reais.
        % predictFreeRun retorna [y0; k amostras simuladas].
        yFull = predictFreeRun(theta, terms, y0, winInputs);
        yPred = yFull(end - k + 1 : end);

        yTrue = y(winStart:winEnd);
        idx = (w - 1) * k + 1 : w * k;
        errosQuad(idx) = (yTrue - yPred).^2;
    end

    mse = mean(errosQuad);
end
