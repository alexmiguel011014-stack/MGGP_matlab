function [melhorModelo, melhorTheta, historico] = evoluir(config)
%EVOLUIR Loop evolutivo completo de MGGP: populacao, selecao por
%   torneio, crossover, mutacao, elitismo e fitness OSA.
%
%   Espelha o papel de mggpEvolver.run() da biblioteca Python original
%   (CastroHc/MGGP) — mesmos parametros de alto nivel (popSize, CXPB,
%   MTPB, n_gen, elite), mesma funcao de fitness padrao (score_osa, ver
%   SCOREOSA), reimplementado porque nao ha equivalente pronto em
%   MATLAB (o DEAP faz esse papel do lado Python).
%
%   ENTRADA
%     config - struct com os campos:
%       vars                - struct de dados (campo 'y' + entradas),
%                             mesmo formato de MAKEREGRESSORS.
%       nomesEntradas        - cell array de nomes de variaveis de
%                             entrada disponiveis para os individuos
%                             (ver GERARINDIVIDUOALEATORIO).
%       maxDelay             - atraso maximo permitido (inteiro >= 1).
%       maxFatoresPorTermo   - fatores maximos por termo.
%       popSize              - tamanho da populacao (default 100).
%       nGeracoes            - numero de geracoes (default 50).
%       cxpb                 - probabilidade de crossover (default 0.9).
%       mtpb                 - probabilidade de mutacao (default 0.1).
%       tamanhoTorneio        - individuos por torneio de selecao
%                             (default 3).
%       elite                - fracao (0 a 1) da populacao preservada
%                             sem alteracao a cada geracao, pelos
%                             melhores fitness (default 0.05 = 5%,
%                             mesmo default da biblioteca original).
%       numTermosInicial      - numero de termos de cada individuo na
%                             populacao inicial (default 3).
%       verbose              - true para imprimir estatisticas por
%                             geracao (default true).
%
%   SAIDAS
%     melhorModelo - MggpModel de menor fitness (OSA) encontrado.
%     melhorTheta  - theta correspondente (estimado via LS sobre vars).
%     historico    - struct array, um elemento por geracao, com campos
%                    'geracao', 'melhorFitness', 'fitnessMedio' — o
%                    equivalente ao "logbook" retornado por
%                    mggpEvolver.run() na biblioteca original.
%
%   TRATAMENTO DE MODELOS INVALIDOS: um individuo pode gerar matriz de
%   regressores singular (LS falha) — a biblioteca original trata isso
%   no proprio 'evaluate' do usuario (try/except retornando Inf, ver
%   exemplo do README). Aqui o mesmo padrao e aplicado internamente em
%   AVALIARINDIVIDUO: fitness = Inf para qualquer individuo cujo LS
%   lance erro, o que efetivamente o exclui da selecao (nunca vence um
%   torneio contra um individuo com fitness finito).
%
%   Ver tambem: MGGPMODEL, GERARINDIVIDUOALEATORIO, CROSSOVERMODELOS,
%   MUTARMODELO, SCOREOSA

    config = aplicarDefaults(config);

    populacao = inicializarPopulacao(config);
    fitnessPop = avaliarPopulacao(populacao, config.vars);

    historico = struct('geracao', {}, 'melhorFitness', {}, 'fitnessMedio', {});

    for geracao = 1:config.nGeracoes
        [populacao, fitnessPop] = proximaGeracao(populacao, fitnessPop, config);

        finitos = fitnessPop(isfinite(fitnessPop));
        if isempty(finitos)
            melhorFitnessGeracao = Inf;
            fitnessMedioGeracao = Inf;
        else
            melhorFitnessGeracao = min(finitos);
            fitnessMedioGeracao = mean(finitos);
        end

        historico(end+1) = struct( ... %#ok<AGROW>
            'geracao', geracao, ...
            'melhorFitness', melhorFitnessGeracao, ...
            'fitnessMedio', fitnessMedioGeracao); %#ok<AGROW>

        if config.verbose
            fprintf('geracao %3d | melhor fitness: %.6g | fitness medio: %.6g\n', ...
                geracao, melhorFitnessGeracao, fitnessMedioGeracao);
        end
    end

    [~, idxMelhor] = min(fitnessPop);
    melhorModelo = populacao(idxMelhor);
    melhorTheta = melhorModelo.estimarTheta(config.vars);
end

function config = aplicarDefaults(config)
%APLICARDEFAULTS Preenche campos opcionais de config com os valores
%   default (mesmos defaults documentados da biblioteca original, onde
%   aplicavel: popSize=100, CXPB=0.9, MTPB=0.1, n_gen=50, elite=5%).
    camposObrigatorios = {'vars', 'nomesEntradas', 'maxDelay', 'maxFatoresPorTermo'};
    for i = 1:numel(camposObrigatorios)
        if ~isfield(config, camposObrigatorios{i})
            error('evoluir:campoObrigatorioFaltando', ...
                'config precisa do campo "%s".', camposObrigatorios{i});
        end
    end

    defaults = struct( ...
        'popSize', 100, ...
        'nGeracoes', 50, ...
        'cxpb', 0.9, ...
        'mtpb', 0.1, ...
        'tamanhoTorneio', 3, ...
        'elite', 0.05, ...
        'numTermosInicial', 3, ...
        'verbose', true);

    nomesDefaults = fieldnames(defaults);
    for i = 1:numel(nomesDefaults)
        campo = nomesDefaults{i};
        if ~isfield(config, campo)
            config.(campo) = defaults.(campo);
        end
    end
end

function populacao = inicializarPopulacao(config)
%INICIALIZARPOPULACAO Gera config.popSize individuos aleatorios validos.
    populacao = MggpModel.empty;
    for i = 1:config.popSize
        individuo = gerarIndividuoAleatorio(config.nomesEntradas, config.maxDelay, ...
            config.numTermosInicial, config.maxFatoresPorTermo);
        populacao = [populacao, individuo]; %#ok<AGROW>
    end
end

function fitnessPop = avaliarPopulacao(populacao, vars)
%AVALIARPOPULACAO Calcula o fitness (OSA) de cada individuo da populacao.
    fitnessPop = zeros(1, numel(populacao));
    for i = 1:numel(populacao)
        fitnessPop(i) = avaliarIndividuo(populacao(i), vars);
    end
end

function fitness = avaliarIndividuo(individuo, vars)
%AVALIARINDIVIDUO Fitness de um individuo, com fallback para Inf se o
%   LS falhar (matriz singular) — mesmo padrao do exemplo README
%   original (try/except retornando Inf). Ver nota de tratamento de
%   erro no cabecalho de EVOLUIR.
    try
        theta = individuo.estimarTheta(vars);
        fitness = individuo.avaliarFitness(theta, vars);
    catch
        fitness = Inf;
    end
end

function [novaPopulacao, novoFitness] = proximaGeracao(populacao, fitnessPop, config)
%PROXIMAGERACAO Produz a proxima geracao: elitismo + reproducao
%   (selecao por torneio, crossover, mutacao) ate completar popSize.

    n = numel(populacao);
    numElite = max(0, round(config.elite * n));

    [~, ordemPorFitness] = sort(fitnessPop, 'ascend');
    idxElite = ordemPorFitness(1:numElite);

    novaPopulacao = populacao(idxElite);
    novoFitness = fitnessPop(idxElite);

    while numel(novaPopulacao) < n
        pai1 = selecionarPorTorneio(populacao, fitnessPop, config.tamanhoTorneio);
        pai2 = selecionarPorTorneio(populacao, fitnessPop, config.tamanhoTorneio);

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

        novaPopulacao = [novaPopulacao, filho1]; %#ok<AGROW>
        novoFitness = [novoFitness, avaliarIndividuo(filho1, config.vars)]; %#ok<AGROW>

        if numel(novaPopulacao) < n
            novaPopulacao = [novaPopulacao, filho2]; %#ok<AGROW>
            novoFitness = [novoFitness, avaliarIndividuo(filho2, config.vars)]; %#ok<AGROW>
        end
    end
end

function selecionado = selecionarPorTorneio(populacao, fitnessPop, tamanhoTorneio)
%SELECIONARPORTORNEIO Sorteia tamanhoTorneio individuos e retorna o de
%   menor fitness (problema de minimizacao, ver AVALIARFITNESS/SCOREOSA).
    n = numel(populacao);
    idxSorteados = randi(n, 1, tamanhoTorneio);
    fitnessSorteados = fitnessPop(idxSorteados);
    [~, idxVencedorLocal] = min(fitnessSorteados);
    selecionado = populacao(idxSorteados(idxVencedorLocal));
end
