function [frontePareto, objetivosFrontePareto, historico] = evoluirNsga2(config)
%EVOLUIRNSGA2 Loop evolutivo multi-objetivo (NSGA-II) para MGGP.
%
%   Nao ha equivalente na biblioteca Python original (CastroHc/MGGP) —
%   o projeto original e mono-objetivo (fitness escalar via score_osa,
%   ver EVOLUIR/SCOREOSA). Esta e uma extensao opcional (passo 7 do
%   plano do projeto), usando o par de objetivos mais comum em GP
%   simbolica na literatura quando nao ha padrao do projeto a seguir:
%
%     objetivo 1: erro one-step-ahead (SCOREOSA) — precisao.
%     objetivo 2: numero de termos do modelo (MggpModel.numTermos()) —
%                 complexidade/parcimonia, evita overfitting e produz
%                 modelos mais interpretaveis junto aos mais precisos.
%
%   Reaproveita os mesmos operadores geneticos de EVOLUIR
%   (GERARINDIVIDUOALEATORIO, CROSSOVERMODELOS, MUTARMODELO) — a
%   diferenca esta inteiramente em como a sobrevivencia e decidida:
%   em vez de elitismo por fitness escalar + torneio, usa o algoritmo
%   classico NSGA-II (Deb et al. 2002): fast non-dominated sort
%   (ORDENACAONAODOMINADA) + crowding distance (DISTANCIAAGLOMERACAO)
%   para selecionar quem sobrevive a cada geracao, preservando um
%   conjunto diverso de solucoes ao longo do trade-off erro-vs-
%   complexidade, em vez de convergir para um unico otimo.
%
%   ENTRADA
%     config - struct com os MESMOS campos obrigatorios de EVOLUIR
%         (vars, nomesEntradas, maxDelay, maxFatoresPorTermo) mais os
%         mesmos opcionais (popSize, nGeracoes, cxpb, mtpb,
%         tamanhoTorneio, numTermosInicial, verbose, usarParfor) —
%         EXCETO 'elite', que nao se aplica aqui (NSGA-II decide
%         sobrevivencia por fronteira de Pareto, nao por elitismo
%         escalar simples).
%
%   SAIDAS
%     frontePareto          - array de MggpModel na fronteira de
%                             Pareto final (nao-dominados entre si).
%     objetivosFrontePareto - matriz numel(frontePareto) x 2, colunas
%                             [erroOsa, numTermos] de cada modelo do
%                             fronte.
%     historico             - struct array, um elemento por geracao,
%                             com campos 'geracao', 'tamanhoFronte',
%                             'menorErro' (menor erroOsa entre toda a
%                             populacao daquela geracao).
%
%   Ver tambem: ORDENACAONAODOMINADA, DISTANCIAAGLOMERACAO, EVOLUIR,
%   MGGPMODEL, SCOREOSA

    config = aplicarDefaultsNsga2(config);

    populacao = inicializarPopulacaoNsga2(config);
    objetivosPop = avaliarObjetivosPopulacao(populacao, config.vars, config.usarParfor);

    historico = struct('geracao', {}, 'tamanhoFronte', {}, 'menorErro', {});

    for geracao = 1:config.nGeracoes
        [populacao, objetivosPop] = proximaGeracaoNsga2(populacao, objetivosPop, config);

        fronteiras = ordenacaoNaoDominada(objetivosPop);
        tamanhoFronte = numel(fronteiras{1});
        errosFinitos = objetivosPop(isfinite(objetivosPop(:,1)), 1);
        if isempty(errosFinitos)
            menorErro = Inf;
        else
            menorErro = min(errosFinitos);
        end

        historico(end+1) = struct( ... %#ok<AGROW>
            'geracao', geracao, ...
            'tamanhoFronte', tamanhoFronte, ...
            'menorErro', menorErro); %#ok<AGROW>

        if config.verbose
            fprintf('geracao %3d | tamanho do fronte: %3d | menor erro: %.6g\n', ...
                geracao, tamanhoFronte, menorErro);
        end
    end

    fronteirasFinal = ordenacaoNaoDominada(objetivosPop);
    idxFronte1 = fronteirasFinal{1};
    frontePareto = populacao(idxFronte1);
    objetivosFrontePareto = objetivosPop(idxFronte1, :);
end

function config = aplicarDefaultsNsga2(config)
%APLICARDEFAULTSNSGA2 Mesmos defaults de EVOLUIR (ver aplicarDefaults
%   em evoluir.m), exceto que 'elite' nao se aplica aqui.
    camposObrigatorios = {'vars', 'nomesEntradas', 'maxDelay', 'maxFatoresPorTermo'};
    for i = 1:numel(camposObrigatorios)
        if ~isfield(config, camposObrigatorios{i})
            error('evoluirNsga2:campoObrigatorioFaltando', ...
                'config precisa do campo "%s".', camposObrigatorios{i});
        end
    end

    defaults = struct( ...
        'popSize', 100, ...
        'nGeracoes', 50, ...
        'cxpb', 0.9, ...
        'mtpb', 0.1, ...
        'tamanhoTorneio', 3, ...
        'numTermosInicial', 3, ...
        'verbose', true, ...
        'usarParfor', false);

    nomesDefaults = fieldnames(defaults);
    for i = 1:numel(nomesDefaults)
        campo = nomesDefaults{i};
        if ~isfield(config, campo)
            config.(campo) = defaults.(campo);
        end
    end
end

function populacao = inicializarPopulacaoNsga2(config)
%INICIALIZARPOPULACAONSGA2 Identico a inicializarPopulacao em evoluir.m
%   — duplicado aqui deliberadamente (funcao local privada de cada
%   arquivo; MATLAB nao compartilha funcoes locais entre arquivos sem
%   um pacote/classe dedicado, e criar um arquivo so para isso seria
%   mais indireto do que duplicar 6 linhas).
    populacao = MggpModel.empty;
    for i = 1:config.popSize
        individuo = gerarIndividuoAleatorio(config.nomesEntradas, config.maxDelay, ...
            config.numTermosInicial, config.maxFatoresPorTermo);
        populacao = [populacao, individuo]; %#ok<AGROW>
    end
end

function objetivos = avaliarObjetivosPopulacao(populacao, vars, usarParfor)
%AVALIAROBJETIVOSPOPULACAO Calcula [erroOsa, numTermos] para cada
%   individuo. Mesmo raciocinio de paralelizacao de AVALIARPOPULACAO em
%   evoluir.m: cada avaliacao e independente, candidata a PARFOR.
    n = numel(populacao);
    objetivos = zeros(n, 2);

    if usarParfor
        parfor i = 1:n
            objetivos(i, :) = avaliarObjetivosIndividuo(populacao(i), vars); %#ok<PFBNS>
        end
    else
        for i = 1:n
            objetivos(i, :) = avaliarObjetivosIndividuo(populacao(i), vars);
        end
    end
end

function obj = avaliarObjetivosIndividuo(individuo, vars)
%AVALIAROBJETIVOSINDIVIDUO [erroOsa, numTermos] de um individuo, com
%   fallback para erroOsa=Inf se o LS falhar (mesmo padrao de
%   AVALIARINDIVIDUO em evoluir.m — um individuo com erro Inf nunca
%   domina nenhum outro em ORDENACAONAODOMINADA, o que o empurra para
%   as ultimas fronteiras, efetivamente excluindo-o da sobrevivencia).
    try
        theta = individuo.estimarTheta(vars);
        erroOsa = individuo.avaliarFitness(theta, vars);
    catch
        erroOsa = Inf;
    end
    obj = [erroOsa, individuo.numTermos()];
end

function [novaPopulacao, novosObjetivos] = proximaGeracaoNsga2(populacao, objetivosPop, config)
%PROXIMAGERACAONSGA2 Um ciclo completo de NSGA-II: gera populacao de
%   filhos (mesmo tamanho da populacao pai), junta pai+filhos (2x o
%   tamanho), e seleciona os melhores popSize individuos por fronteira
%   de Pareto + crowding distance (elitismo multi-objetivo classico do
%   NSGA-II — garante que uma boa solucao nunca e perdida entre
%   geracoes, mesmo sem um "torneio" explicito de sobrevivencia).

    n = numel(populacao);

    filhos = gerarFilhosNsga2(populacao, objetivosPop, config);
    objetivosFilhos = avaliarObjetivosPopulacao(filhos, config.vars, config.usarParfor);

    populacaoCombinada = [populacao, filhos];
    objetivosCombinados = [objetivosPop; objetivosFilhos];

    fronteiras = ordenacaoNaoDominada(objetivosCombinados);

    idxSelecionados = [];
    for f = 1:numel(fronteiras)
        fronteira = fronteiras{f};
        if numel(idxSelecionados) + numel(fronteira) <= n
            idxSelecionados = [idxSelecionados, fronteira]; %#ok<AGROW>
        else
            vagasRestantes = n - numel(idxSelecionados);
            distancias = distanciaAglomeracao(objetivosCombinados, fronteira);
            [~, ordemPorDistancia] = sort(distancias, 'descend');
            idxSelecionados = [idxSelecionados, fronteira(ordemPorDistancia(1:vagasRestantes))]; %#ok<AGROW>
            break;
        end
    end

    novaPopulacao = populacaoCombinada(idxSelecionados);
    novosObjetivos = objetivosCombinados(idxSelecionados, :);
end

function filhos = gerarFilhosNsga2(populacao, objetivosPop, config)
%GERARFILHOSNSGA2 Gera numel(populacao) filhos via selecao por torneio
%   binario baseado em dominancia de Pareto (nao em fitness escalar),
%   crossover e mutacao. Torneio binario por dominancia: entre 2
%   individuos sorteados, vence quem domina o outro; se nenhum domina
%   (nao-dominados entre si), a escolha e aleatoria — criterio padrao
%   de selecao do NSGA-II original.
    n = numel(populacao);
    filhos = MggpModel.empty;

    while numel(filhos) < n
        pai1 = torneioBinarioParento(populacao, objetivosPop);
        pai2 = torneioBinarioParento(populacao, objetivosPop);

        if rand() < config.cxpb
            [filho1, filho2] = crossoverModelos(pai1, pai2, config.maxDelay);
        else
            filho1 = pai1;
            filho2 = pai2;
        end

        if rand() < config.mtpb
            filho1 = mutarModelo(filho1, config.nomesEntradas, config.maxDelay, config.maxFatoresPorTermo);
        end
        if rand() < config.mtpb
            filho2 = mutarModelo(filho2, config.nomesEntradas, config.maxDelay, config.maxFatoresPorTermo);
        end

        filhos = [filhos, filho1]; %#ok<AGROW>
        if numel(filhos) < n
            filhos = [filhos, filho2]; %#ok<AGROW>
        end
    end
end

function selecionado = torneioBinarioParento(populacao, objetivosPop)
%TORNEIOBINARIOPARENTO Sorteia 2 individuos, retorna o que domina o
%   outro; se nenhum domina, escolha aleatoria entre os dois.
    n = numel(populacao);
    idx1 = randi(n);
    idx2 = randi(n);

    obj1 = objetivosPop(idx1, :);
    obj2 = objetivosPop(idx2, :);

    if dominanciaParento(obj1, obj2)
        selecionado = populacao(idx1);
    elseif dominanciaParento(obj2, obj1)
        selecionado = populacao(idx2);
    else
        if rand() < 0.5
            selecionado = populacao(idx1);
        else
            selecionado = populacao(idx2);
        end
    end
end
