function dominaOuIgual = dominanciaParento(objetivos1, objetivos2)
%DOMINANCIAPARENTO Testa se a solucao 1 domina a solucao 2 (Pareto),
%   em um problema de MINIMIZACAO em todos os objetivos.
%
%   dominaOuIgual = DOMINANCIAPARENTO(objetivos1, objetivos2) retorna
%   true se objetivos1 domina objetivos2 — ou seja, objetivos1 e
%   melhor-ou-igual em TODOS os objetivos E estritamente melhor em PELO
%   MENOS UM. Retorna false se objetivos2 domina objetivos1, ou se
%   nenhum domina o outro (solucoes mutuamente nao-dominadas).
%
%   ENTRADAS
%     objetivos1, objetivos2 - vetores linha do mesmo tamanho, cada
%         elemento um objetivo a MINIMIZAR (ex: [erroOsa, numTermos]).
%
%   SAIDA
%     dominaOuIgual - true se objetivos1 domina objetivos2.
%
%   Ver tambem: ORDENACAONAODOMINADA, DISTANCIAAGLOMERACAO

    if numel(objetivos1) ~= numel(objetivos2)
        error('dominanciaParento:tamanhoInvalido', ...
            'objetivos1 e objetivos2 devem ter o mesmo numero de elementos.');
    end

    melhorOuIgualEmTodos = all(objetivos1 <= objetivos2);
    estritamenteMelhorEmAlgum = any(objetivos1 < objetivos2);

    dominaOuIgual = melhorOuIgualEmTodos && estritamenteMelhorEmAlgum;
end
