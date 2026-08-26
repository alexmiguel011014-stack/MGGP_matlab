function Ys = predictFreeRunMimo(modelos, thetas, Y0, inputs, nomesOutputs)
%PREDICTFREERUNMIMO Simula um modelo MIMO em malha aberta (free-run acoplado).
%
%   Ys = PREDICTFREERUNMIMO(modelos, thetas, Y0, inputs, nomesOutputs)
%   simula todas as saidas simultaneamente, passo a passo: cada saida usa
%   os valores JA SIMULADOS das demais saidas nos passos anteriores. Isso
%   propaga o erro ao longo do tempo (free-run real), ao contrario de OSA
%   que usa sempre dados medidos.
%
%   ACOPLAMENTO: a cada passo k, TODOS os modelos sao avaliados usando o
%   estado anterior (k-1, k-2, ...). Como termos MGGP sempre usam atrasos
%   >= 1 para saidas (q1(y), q2(y), etc.), a leitura de Ys no instante k
%   nunca depende do valor calculado no mesmo instante k — causalidade
%   preservada sem copias extras.
%
%   CONVENCAO DE NOMES NOS TERMOS:
%   No treino via EVOLUIRMIMO, a saida `i` foi identificada com 'y' como
%   nome proprio (vars.y = vars.(nomesOutputs{i})). As demais saidas
%   aparecem nos termos pelo nome que tem em nomesOutputs (ex: 'y2').
%   Aqui, 'y' em qualquer termo de modelo i e resolvido para a coluna i
%   de Ys; qualquer outro nome de output e resolvido para a coluna
%   correspondente de Ys. Entradas externas vem de inputs.
%
%   ENTRADAS
%     modelos      - cell array {1 x nOut} de MggpModel, um por saida.
%     thetas       - cell array {1 x nOut} de vetores theta correspondentes.
%     Y0           - matriz [maxLag x nOut] com condicoes iniciais de cada
%                    saida (Y0(end, i) = valor no instante 0 da saida i).
%                    Use pelo menos tantas linhas quanto o maior atraso
%                    presente em qualquer modelo.
%     inputs       - struct de entradas externas a partir do instante 1
%                    (mesmo formato de PREDICTFREERUN). Todos os campos
%                    devem ter o mesmo comprimento (= numPassos).
%     nomesOutputs - cell array {1 x nOut} com o nome de cada saida,
%                    na mesma ordem de modelos/thetas (ex: {'y1','y2'}).
%                    Usado para resolver termos 'q<k>(y2)' etc. no modelo.
%
%   SAIDA
%     Ys - matriz [(maxLag + numPassos) x nOut]:
%          Ys(1:maxLag, :)     = Y0 (condicoes iniciais)
%          Ys(maxLag+1:end, :) = valores simulados
%
%   Ver tambem: EVOLUIRMIMO, PREDICTFREERUN

    nOut = numel(modelos);
    if nOut ~= numel(thetas) || nOut ~= numel(nomesOutputs)
        error('predictFreeRunMimo:tamanhoInvalido', ...
            'modelos, thetas e nomesOutputs devem ter o mesmo numero de elementos.');
    end

    nomesExt = fieldnames(inputs);
    if isempty(nomesExt)
        error('predictFreeRunMimo:inputsVazio', ...
            'inputs deve conter pelo menos uma variavel de entrada externa.');
    end
    numPassos = numel(inputs.(nomesExt{1})(:));
    for k = 1:numel(nomesExt)
        inputs.(nomesExt{k}) = inputs.(nomesExt{k})(:);
        if numel(inputs.(nomesExt{k})) ~= numPassos
            error('predictFreeRunMimo:tamanhoInputsDivergente', ...
                'Todos os campos de inputs devem ter o mesmo tamanho (campo "%s" difere).', ...
                nomesExt{k});
        end
    end

    Y0 = Y0(:, :); % garante matriz
    maxLag = size(Y0, 1);
    if size(Y0, 2) ~= nOut
        error('predictFreeRunMimo:Y0Invalido', ...
            'Y0 deve ter %d colunas (uma por saida). Recebido: %d.', nOut, size(Y0, 2));
    end

    % Compila termos uma vez
    allTerms = cell(nOut, 1);
    for i = 1:nOut
        allTerms{i} = modelos{i}.compile();
    end

    % Eixo de tempo absoluto: linhas 1..maxLag = condicoes iniciais,
    % linhas maxLag+1..maxLag+numPassos = simulacao.
    Ys = [Y0; zeros(numPassos, nOut)];
    offset = maxLag;

    % Entradas externas: prepend historico de zeros (mesmo comprimento das
    % condicoes iniciais), para que o indice absoluto seja identico em
    % Ys e nas entradas — mesma convencao de PREDICTFREERUN.
    historico = zeros(offset, 1);
    varsExt = struct();
    for k = 1:numel(nomesExt)
        nome = nomesExt{k};
        varsExt.(nome) = [historico; inputs.(nome)];
    end

    % Loop de simulacao passo a passo
    for step = 1:numPassos
        idxAtual = offset + step;
        for i = 1:nOut
            terms_i = allTerms{i};
            theta_i = thetas{i}(:);
            acumulado = 0;
            for t = 1:numel(terms_i)
                acumulado = acumulado + theta_i(t) * ...
                    avaliaTermoMimo(terms_i{t}, Ys, i, nomesOutputs, varsExt, idxAtual);
            end
            Ys(idxAtual, i) = acumulado;
        end
    end
end

% =========================================================================
% Funcoes internas de avaliacao de termos
% =========================================================================

function valor = avaliaTermoMimo(termo, Ys, idxSaida, nomesOutputs, varsExt, idxAtual)
%AVALIATERMOMIMO Avalia um termo (produto de fatores) no instante idxAtual.
%   Ys: matriz historica completa [(maxLag+step) x nOut] ate o passo anterior.
%   idxSaida: indice (coluna de Ys) da saida cujo modelo esta sendo avaliado.
%   nomesOutputs: cell{nOut} com nomes de cada saida (na mesma ordem de Ys).

    if strcmp(termo, '1')
        valor = 1;
        return;
    end

    fatores = strsplit(termo, '*');
    valor = 1;
    for k = 1:numel(fatores)
        valor = valor * avaliaFatorMimo(strtrim(fatores{k}), Ys, idxSaida, nomesOutputs, varsExt, idxAtual);
    end
end

function v = avaliaFatorMimo(fator, Ys, idxSaida, nomesOutputs, varsExt, idxAtual)
%AVALIAFATORMIMO Avalia um unico fator no instante idxAtual.
%   'y'   referencia a propria saida do modelo (coluna idxSaida de Ys).
%   nome de outra saida (ex: 'y2') referencia a coluna correspondente de Ys.
%   qualquer outra variavel e buscada em varsExt (entradas externas).

    tok = regexp(fator, '^q(\d+)\((\w+)\)$', 'tokens', 'once');
    if ~isempty(tok)
        atraso = str2double(tok{1});
        nomeVar = tok{2};
        v = resolverVariavelMimo(nomeVar, Ys, idxSaida, nomesOutputs, varsExt, idxAtual - atraso);
        return;
    end

    % Variavel sem atraso (ex: 'u1', 'y', 'y2')
    v = resolverVariavelMimo(fator, Ys, idxSaida, nomesOutputs, varsExt, idxAtual);
end

function v = resolverVariavelMimo(nomeVar, Ys, idxSaida, nomesOutputs, varsExt, idx)
%RESOLVERVARIAVELMIMOAO Resolve o valor de uma variavel num indice absoluto.
%   'y'         -> coluna idxSaida de Ys (propria saida, feedback)
%   nome de outra saida -> coluna correspondente de Ys
%   qualquer outro nome -> entrada externa em varsExt

    % E a propria saida?
    if strcmp(nomeVar, 'y')
        v = Ys(idx, idxSaida);
        return;
    end

    % E uma das outras saidas?
    colOutput = find(strcmp(nomesOutputs, nomeVar), 1);
    if ~isempty(colOutput)
        v = Ys(idx, colOutput);
        return;
    end

    % Entrada externa
    if ~isfield(varsExt, nomeVar)
        error('predictFreeRunMimo:variavelDesconhecida', ...
            'Variavel "%s" nao encontrada em inputs nem em nomesOutputs. Disponiveis: %s.', ...
            nomeVar, strjoin([nomesOutputs(:)', fieldnames(varsExt)'], ', '));
    end
    v = varsExt.(nomeVar)(idx);
end
