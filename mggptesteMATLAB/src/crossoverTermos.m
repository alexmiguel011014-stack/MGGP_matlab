function [filho1, filho2] = crossoverTermos(termoPai1, termoPai2)
%CROSSOVERTERMOS Crossover de 1 ponto entre os fatores de dois termos.
%
%   [filho1, filho2] = CROSSOVERTERMOS(termoPai1, termoPai2) corta cada
%   termo-pai em um ponto aleatorio dentro da sua lista de fatores, e
%   troca os pedacos entre eles — analogo a crossover de 1 ponto em GP
%   de arvore classico, aplicado aqui ao nivel de fatores dentro de um
%   termo (nao ha estrutura de arvore mais profunda que essa: um termo
%   e um produto plano de fatores).
%
%   Termos de 1 fator so nao tem ponto de corte interno — nesse caso o
%   "corte" e trivial (posicao 0 ou 1), e o resultado equivale a trocar
%   o termo inteiro. Isso e esperado, nao um caso de erro.
%
%   ENTRADAS
%     termoPai1, termoPai2 - MggpTerm.
%
%   SAIDAS
%     filho1, filho2 - MggpTerm resultantes da troca. Podem ser iguais
%         a um dos pais se o ponto de corte sorteado nao mudar nada
%         (ex: ambos os pais com 1 fator so).
%
%   Ver tambem: MGGPTERM, GERARINDIVIDUOALEATORIO, MUTARTERMO

    fatores1 = termoPai1.fatores;
    fatores2 = termoPai2.fatores;

    corte1 = randi([0, numel(fatores1)]);
    corte2 = randi([0, numel(fatores2)]);

    novosFatores1 = [fatores1(1:corte1), fatores2((corte2+1):end)];
    novosFatores2 = [fatores2(1:corte2), fatores1((corte1+1):end)];

    if isempty(novosFatores1)
        % roubar do irmão preserva o total de fatores (ao contrário de
        % pegar do pai original, que duplicaria e inflaria a contagem).
        novosFatores1 = novosFatores2(1);
        novosFatores2 = novosFatores2(2:end);
    end
    if isempty(novosFatores2)
        novosFatores2 = novosFatores1(1);
        novosFatores1 = novosFatores1(2:end);
    end

    filho1 = MggpTerm(novosFatores1);
    filho2 = MggpTerm(novosFatores2);
end
