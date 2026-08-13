function y = predictFreeRun(theta, terms, y0, u)
%PREDICTFREERUN Simula um modelo NARX em malha aberta (free-run).
%
%   y = PREDICTFREERUN(theta, terms, y0, u) simula a saida do modelo
%   amostra a amostra, usando SEMPRE saida ja simulada (nunca a saida
%   medida) nos termos que dependem de y — por isso "free-run": o erro
%   de uma amostra se propaga para as seguintes, ao contrario da
%   predicao um-passo-a-frente.
%
%   Espelha mggpElement.predict_freeRun da biblioteca Python original
%   (CastroHc/MGGP).
%
%   CONVENCAO DE INDICES (a mesma de MAKEREGRESSORS, deliberadamente):
%   y e u sao tratados como series alinhadas no MESMO eixo de tempo
%   absoluto, exatamente como em makeRegressors.m. Para isso, u tambem
%   recebe as condicoes iniciais na frente (preenchidas com zero — antes
%   do instante 0, a entrada e considerada nula, convencao padrao para
%   sistemas em repouso). Isso elimina a necessidade de dois offsets
%   separados para y e u: um unico indice absoluto serve para os dois.
%
%   ENTRADAS
%     theta - vetor coluna numel(terms)x1, parametros do modelo (mesma
%             ordem de TERMS; ver LS).
%     terms - cell array de strings, mesma sintaxe de MAKEREGRESSORS
%             ('q<k>(y)', 'q<k>(u)', produtos com '*', ou '1').
%     y0    - condicoes iniciais de y, vetor com pelo menos maxLagUsado
%             amostras (y0(end) = y no instante 0, y0(end-1) = instante
%             -1, etc.).
%     u     - vetor coluna, entrada do sistema A PARTIR DO INSTANTE 0
%             (u(1) = u no instante 0). numel(u) define quantas novas
%             amostras de y sao geradas.
%
%   SAIDA
%     y - vetor coluna com [y0; amostras simuladas], mesmo formato do
%         exemplo do README original (element.predict_freeRun retorna
%         a serie completa incluindo condicoes iniciais no comeco).
%
%   Ver tambem: MAKEREGRESSORS, LS

    y0 = y0(:);
    u = u(:);
    theta = theta(:);

    if numel(terms) ~= numel(theta)
        error('predictFreeRun:tamanhoInvalido', ...
            'theta e terms devem ter o mesmo numero de elementos.');
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

    numPassos = numel(u);

    % Eixo de tempo absoluto comum a y e u: ambos ganham o mesmo prefixo
    % de "historico" antes do instante 0. Para y, o historico e y0 (dado
    % pelo chamador). Para u, o historico antes do instante 0 e
    % convencionado como zero (sistema em repouso antes da simulacao
    % comecar) — mesmo comprimento de y0, para que o indice absoluto
    % seja identico nos dois vetores.
    historicoU = zeros(numel(y0), 1);
    uCompleto = [historicoU; u];
    y = [y0; zeros(numPassos, 1)];

    offset = numel(y0); % indice absoluto do "instante 0" em ambos os vetores

    for k = 1:numPassos
        idxAtual = offset + k; % mesmo indice absoluto em y e em uCompleto
        acumulado = 0;
        for i = 1:numel(terms)
            acumulado = acumulado + theta(i) * avaliaTermoNoInstante( ...
                terms{i}, y, uCompleto, idxAtual);
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

function valor = avaliaTermoNoInstante(termo, y, uCompleto, idxAtual)
%AVALIATERMONOINSTANTE Avalia um termo (possivelmente produto de fatores)
%   em um unico instante de tempo idxAtual — mesmo indice absoluto em y
%   e em uCompleto (ver comentario de convencao no cabecalho da funcao
%   principal).

    if strcmp(termo, '1')
        valor = 1;
        return;
    end

    fatores = strsplit(termo, '*');
    valor = 1;
    for k = 1:numel(fatores)
        valor = valor * avaliaFatorNoInstante(strtrim(fatores{k}), y, uCompleto, idxAtual);
    end
end

function v = avaliaFatorNoInstante(fator, y, uCompleto, idxAtual)
%AVALIAFATORNOINSTANTE Avalia um unico fator no instante idxAtual.
%   Indice absoluto identico para y e uCompleto — ver convencao no
%   cabecalho de predictFreeRun. Para termos em y, usa
%   y(idxAtual - atraso) — sempre valor ja simulado
%   (idxAtual - atraso < idxAtual), garantindo causalidade.
    tok = regexp(fator, '^q(\d+)\((y|u)\)$', 'tokens', 'once');
    if ~isempty(tok)
        atraso = str2double(tok{1});
        variavel = tok{2};
        if strcmp(variavel, 'y')
            v = y(idxAtual - atraso);
        else
            v = uCompleto(idxAtual - atraso);
        end
        return;
    end

    switch fator
        case 'y'
            v = y(idxAtual);
        case 'u'
            v = uCompleto(idxAtual);
        otherwise
            error('predictFreeRun:termoInvalido', ...
                'Termo nao reconhecido: "%s".', fator);
    end
end
