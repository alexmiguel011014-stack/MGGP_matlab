function fronteiras = ordenacaoNaoDominada(matrizObjetivos)
%ORDENACAONAODOMINADA Fast non-dominated sort (Deb et al., NSGA-II).
%
%   fronteiras = ORDENACAONAODOMINADA(matrizObjetivos) particiona os N
%   individuos (linhas de matrizObjetivos) em fronteiras de Pareto:
%   fronteiras{1} = indices dos individuos nao-dominados por nenhum
%   outro (a fronteira otima); fronteiras{2} = nao-dominados se a
%   fronteira 1 fosse removida; e assim por diante.
%
%   ENTRADA
%     matrizObjetivos - matriz N x M, uma linha por individuo, uma
%         coluna por objetivo (todos a MINIMIZAR — ver DOMINANCIAPARENTO).
%
%   SAIDA
%     fronteiras - cell array, fronteiras{k} = vetor de indices (linhas
%         de matrizObjetivos) pertencentes a k-esima fronteira de
%         Pareto, em ordem crescente de dominancia (fronteiras{1} e a
%         melhor).
%
%   Ver tambem: DOMINANCIAPARENTO, DISTANCIAAGLOMERACAO, EVOLUIRNsga2

    n = size(matrizObjetivos, 1);

    contadorDominacao = zeros(n, 1); % quantos individuos dominam o individuo i
    dominados = cell(n, 1);          % dominados{i} = indices que o individuo i domina

    for i = 1:n
        dominados{i} = [];
        for j = 1:n
            if i == j
                continue;
            end
            if dominanciaParento(matrizObjetivos(i, :), matrizObjetivos(j, :))
                dominados{i}(end+1) = j; %#ok<AGROW>
            elseif dominanciaParento(matrizObjetivos(j, :), matrizObjetivos(i, :))
                contadorDominacao(i) = contadorDominacao(i) + 1;
            end
        end
    end

    fronteiras = {};
    fronteiraAtual = find(contadorDominacao == 0)';

    while ~isempty(fronteiraAtual)
        fronteiras{end+1} = fronteiraAtual; %#ok<AGROW>
        proximaFronteira = [];
        for i = fronteiraAtual
            for j = dominados{i}
                contadorDominacao(j) = contadorDominacao(j) - 1;
                if contadorDominacao(j) == 0
                    proximaFronteira(end+1) = j; %#ok<AGROW>
                end
            end
        end
        fronteiraAtual = proximaFronteira;
    end
end
