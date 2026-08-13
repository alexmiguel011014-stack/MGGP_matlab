function [filho1, filho2] = crossoverModelos(modeloPai1, modeloPai2, maxDelay)
%CROSSOVERMODELOS Crossover entre dois MggpModel: sorteia um termo de
%   cada pai e aplica CROSSOVERTERMOS (sub-arvore de fatores) sobre o
%   par sorteado; os demais termos de cada pai sao preservados.
%
%   modelo = CROSSOVERMODELOS(modeloPai1, modeloPai2, maxDelay) produz
%   dois filhos: cada um e uma copia do respectivo pai, exceto pelo
%   termo sorteado, que e substituido pelo resultado do crossover de
%   fatores.
%
%   Se o termo resultante do crossover for identico a outro termo ja
%   presente no modelo (duplicata), o termo original do pai naquela
%   posicao e mantido em vez do resultado do crossover — MggpModel
%   rejeita duplicatas (ver MGGPMODEL), entao a alternativa seria
%   propagar o erro e descartar o filho inteiro; preservar o termo
%   original e um fallback mais barato e ainda produz um filho valido.
%
%   ENTRADAS
%     modeloPai1, modeloPai2 - MggpModel.
%     maxDelay                - atraso maximo permitido nos filhos
%                               (repassado para o construtor de
%                               MggpModel; ver MGGPMODEL).
%
%   SAIDAS
%     filho1, filho2 - MggpModel resultantes.
%
%   Ver tambem: MGGPMODEL, CROSSOVERTERMOS, MUTARTERMO

    if nargin < 3
        maxDelay = Inf;
    end

    termos1 = modeloPai1.termos;
    termos2 = modeloPai2.termos;

    idx1 = randi(numel(termos1));
    idx2 = randi(numel(termos2));

    [novoTermo1, novoTermo2] = crossoverTermos(termos1(idx1), termos2(idx2));

    termosFilho1 = termos1;
    termosFilho1(idx1) = substituirSeNaoDuplicar(termos1, idx1, novoTermo1);

    termosFilho2 = termos2;
    termosFilho2(idx2) = substituirSeNaoDuplicar(termos2, idx2, novoTermo2);

    filho1 = MggpModel(termosFilho1, maxDelay);
    filho2 = MggpModel(termosFilho2, maxDelay);
end

function termoResultante = substituirSeNaoDuplicar(termosOriginais, idxSubstituido, termoCandidato)
%SUBSTITUIRSENAODUPLICAR Retorna termoCandidato, a menos que sua string
%   canonica ja exista em outra posicao de termosOriginais — nesse caso
%   retorna o termo original (sem mudanca), para evitar duplicata.
    stringCandidato = termoCandidato.toString();
    for i = 1:numel(termosOriginais)
        if i == idxSubstituido
            continue;
        end
        if strcmp(termosOriginais(i).toString(), stringCandidato)
            termoResultante = termosOriginais(idxSubstituido);
            return;
        end
    end
    termoResultante = termoCandidato;
end
