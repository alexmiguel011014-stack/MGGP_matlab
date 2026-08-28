function modelo = gerarIndividuoAleatorio(nomesEntradas, maxDelay, numTermos, maxFatoresPorTermo, probConstante)
%GERARINDIVIDUOALEATORIO Gera um MggpModel aleatorio valido.
%
%   modelo = GERARINDIVIDUOALEATORIO(nomesEntradas, maxDelay, numTermos,
%   maxFatoresPorTermo, probConstante) monta um modelo com NUMTERMOS
%   termos distintos, cada um com 1 a MAXFATORESPORTERMO fatores,
%   sorteando variavel ('y' ou uma de NOMESENTRADAS) e atraso (1 a
%   MAXDELAY) para cada fator. Retenta ate gerar termos nao-duplicados
%   (MggpModel rejeita duplicata — ver MGGPMODEL).
%
%   Equivalente ao papel do gerador de individuos inicial que o DEAP
%   fornece pronto na biblioteca Python original (genGrow/genFull);
%   aqui reimplementado porque nao ha equivalente pronto em MATLAB.
%
%   ENTRADAS
%     nomesEntradas       - cell array de strings, nomes das variaveis
%                           de entrada disponiveis (ex: {'u1','u2'}).
%                           'y' e sempre implicitamente disponivel (nao
%                           incluir aqui).
%     maxDelay            - atraso maximo sorteavel para qualquer fator
%                           (inteiro >= 1).
%     numTermos           - quantos termos distintos o modelo tera.
%     maxFatoresPorTermo   - numero maximo de fatores em cada termo
%                           (produto de ate esse tanto de variaveis).
%     probConstante        - probabilidade (0 a 1) de incluir o termo
%                           constante '1' no modelo, alem dos
%                           NUMTERMOS sorteados. Default 0 se omitido.
%
%   SAIDA
%     modelo - MggpModel valido, sem termos duplicados.
%
%   Ver tambem: MGGPMODEL, MGGPTERM, CROSSOVERTERMOS, MUTARTERMO

    if nargin < 5
        probConstante = 0;
    end
    if numTermos < 1
        error('gerarIndividuoAleatorio:numTermosInvalido', ...
            'numTermos deve ser >= 1.');
    end

    variaveisDisponiveis = [{'y'}, nomesEntradas(:)'];

    termos = MggpTerm.empty;
    tentativasMax = numTermos * 50; % evita loop infinito se o espaço de termos possíveis for pequeno
    tentativas = 0;

    while numel(termos) < numTermos
        tentativas = tentativas + 1;
        if tentativas > tentativasMax
            error('gerarIndividuoAleatorio:espacoInsuficiente', ...
                ['Nao foi possivel gerar %d termos distintos apos %d tentativas — ' ...
                 'o espaco de termos possiveis (variaveis x atrasos x fatores) pode ' ...
                 'ser pequeno demais para o numTermos pedido.'], numTermos, tentativasMax);
        end

        numFatores = randi(maxFatoresPorTermo);
        fatoresNovoTermo = MggpTerm.empty;
        for i = 1:numFatores
            variavel = variaveisDisponiveis{randi(numel(variaveisDisponiveis))};
            atraso = randi(maxDelay);
            fatoresNovoTermo = [fatoresNovoTermo, MggpTerm.var(variavel, atraso)]; %#ok<AGROW>
        end
        novoTermo = MggpTerm.produto(fatoresNovoTermo);

        stringsExistentes = arrayfun(@(t) t.toString(), termos, 'UniformOutput', false);
        if ~ismember(novoTermo.toString(), stringsExistentes)
            termos = [termos, novoTermo]; %#ok<AGROW>
        end
    end

    if probConstante > 0 && rand() < probConstante
        termos = [termos, MggpTerm.const()]; %#ok<AGROW>
    end

    modelo = MggpModel(termos, maxDelay);
end
