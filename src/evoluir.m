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
%       usarParfor           - true para paralelizar a avaliacao de
%                             fitness (o gargalo real do loop) via
%                             PARFOR, em vez de FOR sequencial (default
%                             false). Exige o Parallel Computing
%                             Toolbox instalado; se nao estiver
%                             disponivel, MATLAB lanca erro claro ao
%                             tentar abrir o parpool — nao ha fallback
%                             silencioso automatico aqui de proposito
%                             (silenciar esse erro esconderia que a
%                             paralelizacao pedida nao aconteceu).
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
    fitnessPop = avaliarPopulacao(populacao, config.vars, config);

    historico = struct('geracao', {}, 'melhorFitness', {}, 'fitnessMedio', {});

    if config.verbose_timing
        tAcumFitness = 0; tAcumOper = 0; tAcumOverhead = 0;
    end

    for geracao = 1:config.nGeracoes
        if config.verbose_timing
            tInicioGer = tic;
            [populacao, fitnessPop, tOper, tFitness] = proximaGeracao(populacao, fitnessPop, config);
            tAcumOper    = tAcumOper    + tOper;
            tAcumFitness = tAcumFitness + tFitness;
        else
            [populacao, fitnessPop] = proximaGeracao(populacao, fitnessPop, config);
        end

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

        if config.verbose_timing
            tAcumOverhead = tAcumOverhead + toc(tInicioGer) - tOper - tFitness;
        end
    end

    if config.verbose_timing
        tTotal = tAcumOper + tAcumFitness + tAcumOverhead;
        fprintf('\n--- timing breakdown (%d geracoes) ---\n', config.nGeracoes);
        fprintf('  fitness/LS (avaliarPopulacao): %6.2f s  (%4.1f%%)\n', tAcumFitness, 100*tAcumFitness/tTotal);
        fprintf('  operadores geneticos (fase 1): %6.2f s  (%4.1f%%)\n', tAcumOper,    100*tAcumOper/tTotal);
        fprintf('  overhead (sort, historico):    %6.2f s  (%4.1f%%)\n', tAcumOverhead, 100*tAcumOverhead/tTotal);
        fprintf('  total loop: %6.2f s\n', tTotal);
    end

    [~, idxMelhor] = min(fitnessPop);
    melhorModelo = populacao(idxMelhor);
    melhorTheta = melhorModelo.estimarTheta(config.vars);
end

function config = aplicarDefaults(config)
%APLICARDEFAULTS Preenche campos opcionais de config com os valores
%   default (mesmos defaults documentados da biblioteca original, onde
%   aplicavel: popSize=100, CXPB=0.9, MTPB=0.1, n_gen=50, elite=5%).
    camposObrigatorios = {'vars', 'nomesEntradas', 'maxFatoresPorTermo'};
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
        'maxDelay', 5, ...
        'numTermosInicial', 5, ...
        'tipoFitness', 'osa', ...
        'janelaMShooting', 5, ...
        'verbose', true, ...
        'verbose_timing', false, ...
        'usarParfor', false);

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

function fitnessPop = avaliarPopulacao(populacao, vars, config)
%AVALIARPOPULACAO Calcula o fitness de cada individuo da populacao.
%
%   Este e o gargalo real do loop evolutivo: cada avaliacao (LS + fitness)
%   e independente das demais (nenhum individuo le/escreve estado
%   compartilhado), o que a torna um candidato direto para PARFOR sem
%   reestruturar nada — condicao necessaria para paralelizar um loop
%   com parfor (cada iteracao deve ser independente das outras).
%
%   config.usarParfor: se true, usa parfor em vez de for. Default false
%   porque parfor exige o Parallel Computing Toolbox e abrir um parpool
%   (custo fixo de alguns segundos na primeira chamada) — para populacoes
%   pequenas ou uma unica execucao rapida de teste, o overhead de abrir o
%   pool pode superar o ganho.
%
%   config.tipoFitness: 'osa' (default) ou 'mShooting'. Ver SCOREOSA e
%   SCOREMSHOOTING.
%
%   ATENCAO — REPRODUTIBILIDADE: workers de parfor usam gerador de
%   numeros aleatorios PROPRIO, independente do rng() do processo
%   cliente. Isso so e seguro aqui porque AVALIARINDIVIDUO (chamada por
%   este loop) e inteiramente deterministico — nenhum RAND dentro dela.
%   Se um dia essa funcao ganhar qualquer componente estocastico,
%   reprodutibilidade entre execucoes com o mesmo seed deixa de ser
%   garantida dentro do parfor (ver
%   https://www.mathworks.com/help/parallel-computing/control-random-number-streams-on-workers.html
%   para como lidar com isso caso vire necessario).

    n = numel(populacao);
    fitnessPop = zeros(1, n);

    if config.usarParfor
        parfor i = 1:n
            fitnessPop(i) = avaliarIndividuo(populacao(i), vars, config); %#ok<PFBNS>
        end
    else
        for i = 1:n
            fitnessPop(i) = avaliarIndividuo(populacao(i), vars, config);
        end
    end
end

function fitness = avaliarIndividuo(individuo, vars, config)
%AVALIARINDIVIDUO Fitness de um individuo, com fallback para Inf se o
%   LS falhar (matriz singular) — mesmo padrao do exemplo README
%   original (try/except retornando Inf). Ver nota de tratamento de
%   erro no cabecalho de EVOLUIR.
%
%   Despacha para SCOREOSA ou SCOREMSHOOTING conforme config.tipoFitness.
    try
        theta = individuo.estimarTheta(vars);
        switch config.tipoFitness
            case 'osa'
                fitness = individuo.avaliarFitness(theta, vars);
            case 'mShooting'
                fitness = scoreMShooting(theta, individuo.compile(), vars, ...
                    individuo.maiorAtraso(), config.janelaMShooting);
            otherwise
                error('evoluir:tipoFitnessInvalido', ...
                    'config.tipoFitness deve ser ''osa'' ou ''mShooting''. Recebido: ''%s''.', ...
                    config.tipoFitness);
        end
    catch
        fitness = Inf;
    end
end

function [novaPopulacao, novoFitness, tFase1, tFase2] = proximaGeracao(populacao, fitnessPop, config)
%PROXIMAGERACAO Produz a proxima geracao: elitismo + reproducao
%   (selecao por torneio, crossover, mutacao) ate completar popSize.
%
%   Deliberadamente separada em duas fases — (1) gerar todos os filhos,
%   depois (2) avaliar todos os filhos — em vez de avaliar cada filho
%   logo apos gera-lo. A geracao de filho (selecao + crossover +
%   mutacao) e sequencial por natureza (usa RAND, que nao e
%   thread-safe/reprodutivel de forma trivial dentro de PARFOR); a
%   avaliacao (LS + OSA) e o custo real e e independente por filho —
%   so essa fase se beneficia de PARFOR. Juntar as duas fases impediria
%   paralelizar a que realmente importa.

    tInicio1 = tic;

    n = numel(populacao);
    numElite = max(0, round(config.elite * n));

    [~, ordemPorFitness] = sort(fitnessPop, 'ascend');
    idxElite = ordemPorFitness(1:numElite);

    elitePopulacao = populacao(idxElite);
    eliteFitness = fitnessPop(idxElite);

    % Fase 1 (sequencial): gera todos os filhos que faltam.
    numFilhosNecessarios = n - numElite;
    filhos = MggpModel.empty;
    while numel(filhos) < numFilhosNecessarios
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

        filhos = [filhos, filho1]; %#ok<AGROW>
        if numel(filhos) < numFilhosNecessarios
            filhos = [filhos, filho2]; %#ok<AGROW>
        end
    end

    tFase1 = toc(tInicio1);

    % Fase 2 (pode ser paralela): avalia todos os filhos de uma vez.
    tInicio2 = tic;
    fitnessFilhos = avaliarPopulacao(filhos, config.vars, config);
    tFase2 = toc(tInicio2);

    novaPopulacao = [elitePopulacao, filhos];
    novoFitness = [eliteFitness, fitnessFilhos];
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
