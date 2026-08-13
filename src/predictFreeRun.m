function y = predictFreeRun(theta, terms, y0, inputs)
%PREDICTFREERUN Simula um modelo NARX (SISO ou MISO) em malha aberta (free-run).
%
%   y = PREDICTFREERUN(theta, terms, y0, inputs) simula a saida do
%   modelo amostra a amostra, usando SEMPRE saida ja simulada (nunca a
%   saida medida) nos termos que dependem de y — por isso "free-run": o
%   erro de uma amostra se propaga para as seguintes, ao contrario da
%   predicao um-passo-a-frente.
%
%   Espelha mggpElement.predict_freeRun da biblioteca Python original
%   (CastroHc/MGGP), generalizado para MISO.
%
%   CONVENCAO DE INDICES (a mesma de MAKEREGRESSORS, deliberadamente):
%   y e cada variavel de entrada sao tratadas no MESMO eixo de tempo
%   absoluto. Cada entrada recebe um historico de zeros antes do
%   instante 0 (sistema em repouso), do mesmo comprimento de y0 — assim
%   um unico indice absoluto serve para y e para todas as entradas.
%
%   ENTRADAS
%     theta  - vetor coluna numel(terms)x1, parametros do modelo (mesma
%              ordem de TERMS; ver LS).
%     terms  - cell array de strings, mesma sintaxe de MAKEREGRESSORS
%              ('q<k>(<nomeVar>)', '<nomeVar>', produtos com '*', ou '1').
%     y0     - condicoes iniciais de y, vetor com pelo menos
%              maxLagUsado amostras (y0(end) = y no instante 0,
%              y0(end-1) = instante -1, etc.).
%     inputs - struct de series de entrada A PARTIR DO INSTANTE 0 (cada
%              campo: <nomeVar>(1) = valor no instante 0). Nao inclui
%              'y' (isso vem de y0 + do que a propria simulacao gera).
%              numel de cada campo define quantas novas amostras de y
%              sao geradas — todos os campos devem ter o mesmo tamanho.
%
%   SAIDA
%     y - vetor coluna com [y0; amostras simuladas], mesmo formato do
%         exemplo do README original (element.predict_freeRun retorna
%         a serie completa incluindo condicoes iniciais no comeco).
%
%   Ver tambem: MAKEREGRESSORS, LS

    y0 = y0(:);
    theta = theta(:);

    if numel(terms) ~= numel(theta)
        error('predictFreeRun:tamanhoInvalido', ...
            'theta e terms devem ter o mesmo numero de elementos.');
    end

    nomesEntradas = fieldnames(inputs);
    if isempty(nomesEntradas)
        error('predictFreeRun:inputsVazio', ...
            'inputs precisa de pelo menos uma variavel de entrada.');
    end
    numPassos = numel(inputs.(nomesEntradas{1})(:));
    for i = 1:numel(nomesEntradas)
        inputs.(nomesEntradas{i}) = inputs.(nomesEntradas{i})(:);
        if numel(inputs.(nomesEntradas{i})) ~= numPassos
            error('predictFreeRun:tamanhoInputsDivergente', ...
                'Todos os campos de inputs devem ter o mesmo tamanho (campo "%s" difere).', ...
                nomesEntradas{i});
        end
    end

    maxLagUsado = 0;
    for i = 1:numel(terms)
        maxLagUsado = max(maxLagUsado, maiorAtrasoLocal(terms{i}));
    end

    if numel(y0) < maxLagUsado
        error('predictFreeRun:y0Insuficiente', ...
            'y0 tem %d amostras, mas o modelo precisa de pelo menos %d.', ...
            numel(y0), maxLagUsado);
    end

    % Eixo de tempo absoluto comum a y e a todas as entradas: cada uma
    % ganha o mesmo prefixo de "historico" antes do instante 0. Para y,
    % o historico e y0. Para as entradas, o historico antes do instante
    % 0 e convencionado como zero (sistema em repouso) — mesmo
    % comprimento de y0, para que o indice absoluto seja identico em
    % todas as series.
    varsCompletas = struct();
    historico = zeros(numel(y0), 1);
    for i = 1:numel(nomesEntradas)
        nome = nomesEntradas{i};
        varsCompletas.(nome) = [historico; inputs.(nome)];
    end

    y = [y0; zeros(numPassos, 1)];
    offset = numel(y0); % indice absoluto do "instante 0" em todas as series

    for k = 1:numPassos
        idxAtual = offset + k; % mesmo indice absoluto em y e em varsCompletas.*
        acumulado = 0;
        for i = 1:numel(terms)
            acumulado = acumulado + theta(i) * avaliaTermoNoInstante( ...
                terms{i}, y, varsCompletas, idxAtual);
        end
        y(idxAtual) = acumulado;
    end
end

function lag = maiorAtrasoLocal(termo)
%MAIORATRASOLOCAL Mesma logica de maiorAtrasoDoTermo em makeRegressors.m,
%   duplicada aqui deliberadamente: sao arquivos pequenos e independentes,
%   evita acoplar predictFreeRun a funcoes internas (nao exportadas) de
%   outro arquivo.
    if strcmp(termo, '1')
        lag = 0;
        return;
    end
    atrasos = regexp(termo, 'q(\d+)\(', 'tokens');
    if isempty(atrasos)
        lag = 0;
    else
        valores = cellfun(@(c) str2double(c{1}), atrasos);
        lag = max(valores);
    end
end

function valor = avaliaTermoNoInstante(termo, y, varsCompletas, idxAtual)
%AVALIATERMONOINSTANTE Avalia um termo (possivelmente produto de fatores)
%   em um unico instante de tempo idxAtual — mesmo indice absoluto em y
%   e em cada campo de varsCompletas (ver convencao no cabecalho da
%   funcao principal).

    if strcmp(termo, '1')
        valor = 1;
        return;
    end

    fatores = strsplit(termo, '*');
    valor = 1;
    for k = 1:numel(fatores)
        valor = valor * avaliaFatorNoInstante(strtrim(fatores{k}), y, varsCompletas, idxAtual);
    end
end

function v = avaliaFatorNoInstante(fator, y, varsCompletas, idxAtual)
%AVALIAFATORNOINSTANTE Avalia um unico fator no instante idxAtual.
%   Indice absoluto identico para y e para cada campo de varsCompletas
%   (ver convencao no cabecalho de predictFreeRun). Para termos em y,
%   usa y(idxAtual - atraso) — sempre valor ja simulado
%   (idxAtual - atraso < idxAtual), garantindo causalidade.
    tok = regexp(fator, '^q(\d+)\((\w+)\)$', 'tokens', 'once');
    if ~isempty(tok)
        atraso = str2double(tok{1});
        nomeVar = tok{2};
        if strcmp(nomeVar, 'y')
            v = y(idxAtual - atraso);
        else
            v = obterSerieEntrada(varsCompletas, nomeVar, idxAtual - atraso);
        end
        return;
    end

    if strcmp(fator, 'y')
        v = y(idxAtual);
        return;
    end

    v = obterSerieEntrada(varsCompletas, fator, idxAtual);
end

function v = obterSerieEntrada(varsCompletas, nomeVar, idx)
%OBTERSERIEENTRADA Busca o valor de uma variavel de entrada no indice
%   absoluto idx, com erro claro se o nome nao existir.
    if ~isfield(varsCompletas, nomeVar)
        error('predictFreeRun:variavelDesconhecida', ...
            'Variavel "%s" nao encontrada em inputs. Campos disponiveis: %s.', ...
            nomeVar, strjoin(fieldnames(varsCompletas), ', '));
    end
    v = varsCompletas.(nomeVar)(idx);
end
