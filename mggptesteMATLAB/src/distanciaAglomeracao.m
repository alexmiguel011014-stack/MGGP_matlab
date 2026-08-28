function distancias = distanciaAglomeracao(matrizObjetivos, indicesFronteira)
%DISTANCIAAGLOMERACAO Crowding distance (Deb et al., NSGA-II) para os
%   individuos de uma unica fronteira de Pareto.
%
%   distancias = DISTANCIAAGLOMERACAO(matrizObjetivos, indicesFronteira)
%   calcula, para cada individuo em indicesFronteira, o quao "isolado"
%   ele esta dos vizinhos na mesma fronteira (soma, por objetivo, da
%   distancia normalizada aos vizinhos mais proximos nesse objetivo).
%   Individuos nos extremos de cada objetivo recebem distancia Inf
%   (sempre preservados — preserva os extremos do trade-off).
%
%   Usado como criterio de desempate quando a fronteira nao cabe
%   inteira na proxima geracao: preferir individuos com maior distancia
%   (mais espalhados) mantem diversidade ao longo do Pareto front, em
%   vez de a populacao colapsar em um unico ponto do trade-off.
%
%   ENTRADAS
%     matrizObjetivos  - matriz N x M (todos os individuos), mesmo
%                        formato de ORDENACAONAODOMINADA.
%     indicesFronteira - vetor de indices (linhas de matrizObjetivos)
%                        pertencentes a UMA fronteira (ex:
%                        fronteiras{k} de ORDENACAONAODOMINADA).
%
%   SAIDA
%     distancias - vetor, mesma ordem de indicesFronteira, com a
%                 crowding distance de cada individuo.
%
%   Ver tambem: ORDENACAONAODOMINADA, EVOLUIRNsga2

    numIndividuos = numel(indicesFronteira);
    numObjetivos = size(matrizObjetivos, 2);

    distancias = zeros(numIndividuos, 1);

    if numIndividuos <= 2
        % com 1 ou 2 individuos, ambos os extremos -- todos recebem Inf
        % (nao ha "meio" a distinguir).
        distancias(:) = Inf;
        return;
    end

    for m = 1:numObjetivos
        valoresObjetivo = matrizObjetivos(indicesFronteira, m);
        [valoresOrdenados, ordemLocal] = sort(valoresObjetivo, 'ascend');

        distancias(ordemLocal(1)) = Inf;
        distancias(ordemLocal(end)) = Inf;

        intervaloObjetivo = valoresOrdenados(end) - valoresOrdenados(1);
        if intervaloObjetivo == 0
            continue; % todos os individuos tem o mesmo valor neste objetivo -- sem contribuicao
        end

        for k = 2:(numIndividuos - 1)
            idxLocal = ordemLocal(k);
            if isinf(distancias(idxLocal))
                continue; % ja e extremo em outro objetivo, mantem Inf
            end
            contribuicao = (valoresOrdenados(k+1) - valoresOrdenados(k-1)) / intervaloObjetivo;
            distancias(idxLocal) = distancias(idxLocal) + contribuicao;
        end
    end
end
