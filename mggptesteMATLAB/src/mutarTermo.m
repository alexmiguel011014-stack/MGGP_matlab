function termoMutado = mutarTermo(termo, nomesEntradas, maxDelay, maxFatoresPorTermo)
%MUTARTERMO Aplica uma mutacao aleatoria a um MggpTerm.
%
%   termoMutado = MUTARTERMO(termo, nomesEntradas, maxDelay,
%   maxFatoresPorTermo) sorteia uma entre tres mutacoes possiveis, com
%   peso igual, respeitando os limites do problema:
%     - trocarFator:  substitui um fator existente por outro sorteado
%                     (variavel e/ou atraso novos).
%     - adicionarFator: acrescenta um novo fator ao produto, se o termo
%                     ainda nao estiver no limite MAXFATORESPORTERMO.
%     - removerFator: remove um fator do produto, se o termo tiver mais
%                     de 1 fator (um termo precisa de pelo menos 1).
%   Mutacoes que nao se aplicam (ex: adicionar quando ja esta no limite)
%   sao puladas silenciosamente na hora do sorteio, redistribuindo a
%   chance entre as que restam.
%
%   Equivalente ao papel do mutUniform/mutNodeReplacement que o DEAP
%   fornece pronto na biblioteca Python original; aqui reimplementado
%   porque nao ha equivalente pronto em MATLAB.
%
%   ENTRADAS
%     termo               - MggpTerm a mutar.
%     nomesEntradas        - cell array de strings, variaveis de entrada
%                            disponiveis (sem incluir 'y', que e sempre
%                            implicitamente disponivel).
%     maxDelay             - atraso maximo sorteavel.
%     maxFatoresPorTermo   - numero maximo de fatores permitido no termo.
%
%   SAIDA
%     termoMutado - novo MggpTerm com a mutacao aplicada. O termo
%         original nunca e modificado (MggpTerm e imutavel).
%
%   Ver tambem: MGGPTERM, CROSSOVERTERMOS, GERARINDIVIDUOALEATORIO

    variaveisDisponiveis = [{'y'}, nomesEntradas(:)'];
    numFatoresAtual = numel(termo.fatores);

    opcoesDisponiveis = {'trocarFator'};
    if numFatoresAtual < maxFatoresPorTermo
        opcoesDisponiveis{end+1} = 'adicionarFator';
    end
    if numFatoresAtual > 1
        opcoesDisponiveis{end+1} = 'removerFator';
    end

    operacao = opcoesDisponiveis{randi(numel(opcoesDisponiveis))};

    switch operacao
        case 'trocarFator'
            idx = randi(numFatoresAtual);
            novaVariavel = variaveisDisponiveis{randi(numel(variaveisDisponiveis))};
            novoAtraso = randi(maxDelay);
            novosFatores = termo.fatores;
            novosFatores(idx) = struct('variavel', novaVariavel, 'atraso', novoAtraso);

        case 'adicionarFator'
            novaVariavel = variaveisDisponiveis{randi(numel(variaveisDisponiveis))};
            novoAtraso = randi(maxDelay);
            novoFator = struct('variavel', novaVariavel, 'atraso', novoAtraso);
            novosFatores = [termo.fatores, novoFator];

        case 'removerFator'
            idx = randi(numFatoresAtual);
            novosFatores = termo.fatores;
            novosFatores(idx) = [];
    end

    termoMutado = MggpTerm(novosFatores);
end
