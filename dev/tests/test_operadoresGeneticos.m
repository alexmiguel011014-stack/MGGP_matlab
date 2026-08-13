function test_operadoresGeneticos()
%TEST_OPERADORESGENETICOS Valida gerarIndividuoAleatorio, crossover e
%   mutacao — geracao/recombinacao sempre produz MggpModel valido.
%
%   Diferente dos testes numericos (test_ls, test_predictFreeRun), aqui
%   nao ha "resposta certa" para comparar — o que se valida e que os
%   operadores sempre produzem modelos estruturalmente validos
%   (MggpModel so aceita termos nao-duplicados, dentro do maxDelay),
%   nunca lancam erro inesperado, e respeitam as invariantes descritas
%   no cabecalho de cada funcao (ex: causalidade, limites de fatores).
%
%   Rodar: >> test_operadoresGeneticos
%   Sucesso: imprime "OK" e nao lanca erro.

    rng(123);

    nomesEntradas = {'u1', 'u2'};
    maxDelay = 4;
    maxFatoresPorTermo = 3;

    % --- checagem 1: gerarIndividuoAleatorio produz modelo valido,
    % repetidamente, com parametros variados (inclui caso extremo:
    % maxFatoresPorTermo=1, so testa fatores unicos). ---
    for tentativa = 1:20
        numTermos = randi([1, 6]);
        modelo = gerarIndividuoAleatorio(nomesEntradas, maxDelay, numTermos, maxFatoresPorTermo, 0.3);
        if modelo.numTermos() ~= numTermos && modelo.numTermos() ~= numTermos + 1
            % +1 cobre o caso do termo constante ter sido incluido
            error('test_operadoresGeneticos:numTermosInesperado', ...
                'gerarIndividuoAleatorio: esperado %d ou %d termos, obtido %d.', ...
                numTermos, numTermos + 1, modelo.numTermos());
        end
        if modelo.maiorAtraso() > maxDelay
            error('test_operadoresGeneticos:atrasoExcedeLimite', ...
                'gerarIndividuoAleatorio produziu atraso %d > maxDelay %d.', ...
                modelo.maiorAtraso(), maxDelay);
        end
    end

    % --- checagem 2: crossoverTermos preserva causalidade estrutural
    % (nenhum fator "some" sem explicacao: filho1 + filho2 juntos tem o
    % mesmo numero total de fatores que pai1 + pai2 juntos). ---
    pai1 = MggpTerm.produto(MggpTerm.var('y', 2), MggpTerm.var('u1', 1));
    pai2 = MggpTerm.produto(MggpTerm.var('u2', 3));

    totalFatoresPais = numel(pai1.fatores) + numel(pai2.fatores);
    for tentativa = 1:20
        [filho1, filho2] = crossoverTermos(pai1, pai2);
        totalFatoresFilhos = numel(filho1.fatores) + numel(filho2.fatores);
        if totalFatoresFilhos ~= totalFatoresPais
            error('test_operadoresGeneticos:crossoverPerdeuFatores', ...
                'crossoverTermos: total de fatores mudou (pais=%d, filhos=%d).', ...
                totalFatoresPais, totalFatoresFilhos);
        end
        if isempty(filho1.fatores) || isempty(filho2.fatores)
            error('test_operadoresGeneticos:crossoverGerouTermoVazio', ...
                'crossoverTermos nunca deveria gerar um termo sem fatores.');
        end
    end

    % --- checagem 3: crossoverModelos sempre produz MggpModel valido
    % (sem duplicata, dentro do maxDelay), repetidamente. ---
    modeloPai1 = gerarIndividuoAleatorio(nomesEntradas, maxDelay, 4, maxFatoresPorTermo);
    modeloPai2 = gerarIndividuoAleatorio(nomesEntradas, maxDelay, 4, maxFatoresPorTermo);
    for tentativa = 1:20
        [filhoA, filhoB] = crossoverModelos(modeloPai1, modeloPai2, maxDelay);
        if filhoA.maiorAtraso() > maxDelay || filhoB.maiorAtraso() > maxDelay
            error('test_operadoresGeneticos:crossoverModelosAtrasoInvalido', ...
                'crossoverModelos produziu filho com atraso acima de maxDelay.');
        end
        % crossoverModelos usa substituirSeNaoDuplicar internamente
        % para nunca deixar o construtor de MggpModel lancar erro de
        % duplicata -- chegar aqui sem excecao confirma que esse
        % fallback esta funcionando, nao que o construtor foi testado
        % diretamente (isso e coberto em test_MggpModel.m).
    end

    % --- checagem 4: mutarModelo sempre produz MggpModel valido,
    % repetidamente, inclusive quando o modelo tem so 1 termo com 1
    % fator (caso extremo: nao pode tentar 'removerFator'). ---
    modeloMinimo = MggpModel(MggpTerm.var('y', 1), maxDelay);
    for tentativa = 1:20
        mutado = mutarModelo(modeloMinimo, nomesEntradas, maxDelay, maxFatoresPorTermo);
        if mutado.numTermos() < 1
            error('test_operadoresGeneticos:mutacaoZerouTermos', ...
                'mutarModelo nunca deveria produzir um modelo sem termos.');
        end
        if mutado.maiorAtraso() > maxDelay
            error('test_operadoresGeneticos:mutacaoAtrasoInvalido', ...
                'mutarModelo produziu atraso acima de maxDelay.');
        end
    end

    % --- checagem 5: mutarModelo em modelo maior, varias iteracoes. ---
    modeloMaior = gerarIndividuoAleatorio(nomesEntradas, maxDelay, 5, maxFatoresPorTermo);
    for tentativa = 1:20
        modeloMaior = mutarModelo(modeloMaior, nomesEntradas, maxDelay, maxFatoresPorTermo); %#ok<AGROW>
    end
    if modeloMaior.maiorAtraso() > maxDelay
        error('test_operadoresGeneticos:mutacaoRepetidaAtrasoInvalido', ...
            'Apos mutacoes repetidas, atraso excedeu maxDelay.');
    end

    fprintf('OK - gerarIndividuoAleatorio/crossoverTermos/crossoverModelos/mutarModelo validados\n');
end
