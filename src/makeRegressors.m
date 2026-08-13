function P = makeRegressors(y, u, terms, maxDelay)
%MAKEREGRESSORS Monta a matriz de regressores de um modelo NARX.
%
%   P = MAKEREGRESSORS(y, u, terms, maxDelay) monta a matriz de
%   regressores P a partir dos sinais de saida y e entrada u, aplicando
%   os termos descritos em TERMS (com atraso), alinhados em amostras
%   validas (a partir de maxDelay+1).
%
%   Espelha mggpElement.makeRegressors da biblioteca Python original
%   (CastroHc/MGGP), no modo 'default' (sem MA/ruido).
%
%   ENTRADAS
%     y        - vetor coluna Nx1, saida medida do sistema.
%     u        - vetor coluna Nx1, entrada do sistema.
%     terms    - cell array de strings, cada uma um termo do modelo.
%                Sintaxe suportada:
%                  'q<k>(y)'        -> y atrasado k amostras: y(t-k)
%                  'q<k>(u)'        -> u atrasado k amostras: u(t-k)
%                  'q<k>(y)*q<j>(u)' -> produto de dois regressores
%                  '1'              -> termo constante
%                Exemplo: {'q2(y)', 'q1(u)', 'q2(y)*q1(u)'} representa
%                y(k-2), u(k-1), y(k-2)*u(k-1).
%     maxDelay - atraso maximo considerado no primitive set (usado so
%                para validar que nenhum termo excede o combinado com o
%                resto do motor de GP; nao afeta o calculo em si).
%
%   SAIDA
%     P - matriz de regressores, (N - maxLagUsado) x numel(terms).
%         Cada coluna corresponde a um termo de TERMS, alinhada nas
%         mesmas amostras (as primeiras maxLagUsado amostras de y/u sao
%         descartadas por nao terem historico suficiente).
%
%   Ver tambem: LS, PREDICTFREERUN

    if nargin < 4
        maxDelay = Inf;
    end

    y = y(:);
    u = u(:);
    if numel(y) ~= numel(u)
        error('makeRegressors:tamanhoInvalido', ...
            'y e u devem ter o mesmo numero de amostras.');
    end

    numTerms = numel(terms);
    lagsUsados = zeros(numTerms, 1);

    % Primeira passada: descobre o maior atraso usado em qualquer termo,
    % para saber quantas amostras iniciais descartar (todas as colunas
    % precisam estar alinhadas na mesma janela de tempo valida).
    for i = 1:numTerms
        lagsUsados(i) = maiorAtrasoDoTermo(terms{i});
    end
    maxLagUsado = max(lagsUsados);

    if isfinite(maxDelay) && maxLagUsado > maxDelay
        error('makeRegressors:atrasoExcedeMaxDelay', ...
            'Um termo usa atraso %d, maior que maxDelay=%d.', ...
            maxLagUsado, maxDelay);
    end

    N = numel(y);
    numAmostrasValidas = N - maxLagUsado;
    if numAmostrasValidas <= 0
        error('makeRegressors:dadosInsuficientes', ...
            'Serie com %d amostras nao comporta atraso maximo %d.', ...
            N, maxLagUsado);
    end

    P = zeros(numAmostrasValidas, numTerms);
    for i = 1:numTerms
        P(:, i) = avaliaTermo(terms{i}, y, u, maxLagUsado, numAmostrasValidas);
    end
end

function lag = maiorAtrasoDoTermo(termo)
%MAIORATRASODOTERMO Extrai o maior atraso q<k> presente numa string de termo.
    if strcmp(termo, '1')
        lag = 0;
        return;
    end
    atrasos = regexp(termo, 'q(\d+)\(', 'tokens');
    if isempty(atrasos)
        lag = 0; % termo sem atraso, ex: 'u' puro
    else
        valores = cellfun(@(c) str2double(c{1}), atrasos);
        lag = max(valores);
    end
end

function coluna = avaliaTermo(termo, y, u, maxLagUsado, numAmostrasValidas)
%AVALIATERMO Avalia um unico termo do modelo em todas as amostras validas.
%   Amostras validas comecam no indice (maxLagUsado + 1) da serie
%   original, para que todo termo tenha historico suficiente.

    idxInicio = maxLagUsado + 1;
    idxFim = idxInicio + numAmostrasValidas - 1;

    if strcmp(termo, '1')
        coluna = ones(numAmostrasValidas, 1);
        return;
    end

    % Suporta produto de até dois fatores separados por '*'.
    fatores = strsplit(termo, '*');
    coluna = ones(numAmostrasValidas, 1);
    for k = 1:numel(fatores)
        coluna = coluna .* avaliaFator(strtrim(fatores{k}), y, u, idxInicio, idxFim);
    end
end

function valores = avaliaFator(fator, y, u, idxInicio, idxFim)
%AVALIAFATOR Avalia um único fator (ex: 'q2(y)' ou 'u') na janela [idxInicio, idxFim].
    tok = regexp(fator, '^q(\d+)\((y|u)\)$', 'tokens', 'once');
    if ~isempty(tok)
        atraso = str2double(tok{1});
        variavel = tok{2};
        if strcmp(variavel, 'y')
            serie = y;
        else
            serie = u;
        end
        valores = serie((idxInicio - atraso):(idxFim - atraso));
        return;
    end

    switch fator
        case 'y'
            valores = y(idxInicio:idxFim);
        case 'u'
            valores = u(idxInicio:idxFim);
        otherwise
            error('makeRegressors:termoInvalido', ...
                'Termo nao reconhecido: "%s". Use q<k>(y), q<k>(u), y, u ou "1".', fator);
    end
end
