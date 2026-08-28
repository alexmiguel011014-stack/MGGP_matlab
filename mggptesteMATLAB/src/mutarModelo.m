function modeloMutado = mutarModelo(modelo, nomesEntradas, maxDelay, maxFatoresPorTermo)
%MUTARMODELO Aplica MUTARTERMO a um termo sorteado de um MggpModel.
%
%   modeloMutado = MUTARMODELO(modelo, nomesEntradas, maxDelay,
%   maxFatoresPorTermo) sorteia um termo do modelo e o substitui pela
%   versao mutada (ver MUTARTERMO). Os demais termos sao preservados.
%
%   Se o termo mutado colidir com outro termo ja existente no modelo
%   (duplicata), o termo original naquela posicao e mantido em vez do
%   resultado da mutacao — mesmo fallback usado em CROSSOVERMODELOS,
%   pelo mesmo motivo (MggpModel rejeita duplicatas).
%
%   ENTRADAS
%     modelo               - MggpModel a mutar.
%     nomesEntradas, maxDelay, maxFatoresPorTermo - repassados para
%         MUTARTERMO.
%
%   SAIDA
%     modeloMutado - novo MggpModel com a mutacao aplicada.
%
%   Ver tambem: MGGPMODEL, MUTARTERMO, CROSSOVERMODELOS

    termos = modelo.termos;
    idx = randi(numel(termos));

    termoMutado = mutarTermo(termos(idx), nomesEntradas, maxDelay, maxFatoresPorTermo);

    stringMutado = termoMutado.toString();
    duplicata = false;
    for i = 1:numel(termos)
        if i == idx
            continue;
        end
        if strcmp(termos(i).toString(), stringMutado)
            duplicata = true;
            break;
        end
    end

    novosTermos = termos;
    if ~duplicata
        novosTermos(idx) = termoMutado;
    end
    % se duplicata, novosTermos permanece igual a termos -- modelo
    % retornado e equivalente ao original (mutacao "falhou" de forma
    % segura, sem gerar modelo invalido).

    modeloMutado = MggpModel(novosTermos, maxDelay);
end
