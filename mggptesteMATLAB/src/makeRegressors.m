function P = makeRegressors(vars, terms, maxDelay)
%MAKEREGRESSORS Monta a matriz de regressores de um modelo NARX (SISO ou MISO).
%
%   P = MAKEREGRESSORS(vars, terms, maxDelay) monta a matriz de
%   regressores P a partir das series em VARS, aplicando os termos
%   descritos em TERMS (com atraso), alinhados em amostras validas.
%
%   Espelha mggpElement.makeRegressors da biblioteca Python original
%   (CastroHc/MGGP), no modo 'default' (sem MA/ruido), generalizado para
%   MISO (numero arbitrario de variaveis de entrada, nao so 'y'/'u'
%   fixos).
%
%   ENTRADAS
%     vars     - struct de series de tempo, cada campo um vetor coluna
%                Nx1 do MESMO tamanho. Deve conter pelo menos o campo
%                'y' (saida do sistema). Os demais campos sao as
%                variaveis de entrada, com qualquer nome (ex: vars.y,
%                vars.u1, vars.h1 — mesma convencao de nomes da
%                biblioteca original, sufixo '1' sugerido mas nao
%                exigido).
%     terms    - cell array de strings, cada uma um termo do modelo.
%                Sintaxe suportada:
%                  'q<k>(<nomeVar>)'  -> variavel atrasada k amostras
%                  '<nomeVar>'        -> variavel sem atraso
%                  '<fator>*<fator>'  -> produto de fatores (2 ou mais)
%                  '1'                -> termo constante
%                <nomeVar> deve ser um campo existente em VARS.
%                Exemplo: {'q2(y)', 'q1(u1)', 'q2(y)*q1(u1)'} representa
%                y(k-2), u1(k-1), y(k-2)*u1(k-1).
%     maxDelay - atraso maximo considerado no primitive set (usado so
%                para validar que nenhum termo excede o combinado com o
%                resto do motor de GP; nao afeta o calculo em si).
%
%   SAIDA
%     P - matriz de regressores, (N - maxLagUsado) x (numel(terms) + 1).
%         Coluna 1 e sempre ones (termo de bias implicito, identico ao
%         comportamento de IndividualMISO.makeRegressors na biblioteca
%         Python original). Colunas 2..end correspondem aos termos de
%         TERMS, alinhadas nas mesmas amostras validas.
%
%   Ver tambem: LS, PREDICTFREERUN

    if nargin < 3
        maxDelay = Inf;
    end

    if ~isfield(vars, 'y')
        error('makeRegressors:campoYObrigatorio', ...
            'vars deve ter pelo menos o campo ''y'' (saida do sistema).');
    end

    nomesVars = fieldnames(vars);
    N = numel(vars.y(:));
    for i = 1:numel(nomesVars)
        vars.(nomesVars{i}) = vars.(nomesVars{i})(:);
        if numel(vars.(nomesVars{i})) ~= N
            error('makeRegressors:tamanhoInvalido', ...
                'Todas as series em vars devem ter o mesmo numero de amostras (campo "%s" difere).', ...
                nomesVars{i});
        end
    end

    numTerms = numel(terms);
    lagsUsados = zeros(numTerms, 1);
    for i = 1:numTerms
        lagsUsados(i) = maiorAtrasoDoTermo(terms{i});
    end
    maxLagUsado = max(lagsUsados);

    if isfinite(maxDelay) && maxLagUsado > maxDelay
        error('makeRegressors:atrasoExcedeMaxDelay', ...
            'Um termo usa atraso %d, maior que maxDelay=%d.', ...
            maxLagUsado, maxDelay);
    end

    numAmostrasValidas = N - maxLagUsado;
    if numAmostrasValidas <= 0
        error('makeRegressors:dadosInsuficientes', ...
            'Serie com %d amostras nao comporta atraso maximo %d.', ...
            N, maxLagUsado);
    end

    P = [ones(numAmostrasValidas, 1), zeros(numAmostrasValidas, numTerms)];
    for i = 1:numTerms
        P(:, i + 1) = avaliaTermo(terms{i}, vars, maxLagUsado, numAmostrasValidas);
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
        lag = 0; % termo sem atraso, ex: 'u1' puro
    else
        valores = cellfun(@(c) str2double(c{1}), atrasos);
        lag = max(valores);
    end
end

function coluna = avaliaTermo(termo, vars, maxLagUsado, numAmostrasValidas)
%AVALIATERMO Avalia um unico termo do modelo em todas as amostras validas.
%   Amostras validas comecam no indice (maxLagUsado + 1) da serie
%   original, para que todo termo tenha historico suficiente.

    idxInicio = maxLagUsado + 1;
    idxFim = idxInicio + numAmostrasValidas - 1;

    if strcmp(termo, '1')
        coluna = ones(numAmostrasValidas, 1);
        return;
    end

    fatores = strsplit(termo, '*');
    coluna = ones(numAmostrasValidas, 1);
    for k = 1:numel(fatores)
        coluna = coluna .* avaliaFator(strtrim(fatores{k}), vars, idxInicio, idxFim);
    end
end

function valores = avaliaFator(fator, vars, idxInicio, idxFim)
%AVALIAFATOR Avalia um unico fator (ex: 'q2(y)' ou 'u1') na janela [idxInicio, idxFim].
    tok = regexp(fator, '^q(\d+)\((\w+)\)$', 'tokens', 'once');
    if ~isempty(tok)
        atraso = str2double(tok{1});
        nomeVar = tok{2};
        serie = obterSerie(vars, nomeVar);
        valores = serie((idxInicio - atraso):(idxFim - atraso));
        return;
    end

    % variavel sem atraso: precisa ser um nome de campo valido de vars.
    if isfield(vars, fator)
        serie = vars.(fator);
        valores = serie(idxInicio:idxFim);
        return;
    end

    error('makeRegressors:termoInvalido', ...
        'Termo nao reconhecido: "%s". Use q<k>(<var>), <var> (campo existente em vars) ou "1".', fator);
end

function serie = obterSerie(vars, nomeVar)
%OBTERSERIE Busca a serie de uma variavel em vars, com erro claro se nao existir.
    if ~isfield(vars, nomeVar)
        error('makeRegressors:variavelDesconhecida', ...
            'Variavel "%s" nao encontrada em vars. Campos disponiveis: %s.', ...
            nomeVar, strjoin(fieldnames(vars), ', '));
    end
    serie = vars.(nomeVar);
end
