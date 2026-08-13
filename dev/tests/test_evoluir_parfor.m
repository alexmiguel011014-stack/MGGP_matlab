function test_evoluir_parfor()
%TEST_EVOLUIR_PARFOR Valida que usarParfor=true produz resultado
%   equivalente a usarParfor=false, para o mesmo seed/config.
%
%   IMPORTANTE: este teste exige o Parallel Computing Toolbox
%   instalado (abre um parpool na primeira chamada com parfor — pode
%   demorar alguns segundos a mais que os outros testes por causa
%   disso). Se o toolbox nao estiver disponivel, MATLAB lanca um erro
%   claro ao tentar rodar — isso e o comportamento esperado, nao um bug
%   deste teste (ver nota "usarParfor" no cabecalho de evoluir.m).
%
%   Criterio: como a fase de GERACAO de filhos (selecao, crossover,
%   mutacao) e sempre sequencial, e so a fase de AVALIACAO roda em
%   parfor quando usarParfor=true, os individuos gerados devem ser
%   exatamente os mesmos com o mesmo seed — logo o fitness de cada um
%   tambem deve ser exatamente igual entre as duas execucoes (parfor
%   nao muda o RESULTADO da avaliacao, so a ORDEM/tempo de execucao).
%
%   ATENCAO PARA QUEM EXPANDIR ESTE CODIGO: workers de parfor usam um
%   gerador de numeros aleatorios PROPRIO e independente do processo
%   cliente (rng() no cliente nao propaga para dentro do parfor) — ver
%   https://www.mathworks.com/help/parallel-computing/control-random-number-streams-on-workers.html.
%   Este teste so e valido porque AVALIARINDIVIDUO/ESTIMARTHETA/
%   AVALIARFITNESS sao inteiramente deterministicos (algebra linear
%   pura, sem RAND em lugar nenhum) — se algum dia RAND for adicionado
%   dentro do que roda em parfor (ex: um fitness com componente
%   estocastico), este teste de equivalencia par de quebrar SEM avisar
%   com um erro claro (silenciosamente deixaria de ser reprodutivel).
%
%   Rodar: >> test_evoluir_parfor
%   Sucesso: imprime "OK" e nao lanca erro.

    N = 300;
    thetaVerdadeiro = [0.75; 0.25; -0.20];

    configBase = struct();
    configBase.nomesEntradas = {'u1'};
    configBase.maxDelay = 3;
    configBase.maxFatoresPorTermo = 2;
    configBase.popSize = 20;   % pequeno de proposito -- so testa equivalencia, nao desempenho
    configBase.nGeracoes = 5;
    configBase.verbose = false;

    % --- execucao sequencial ---
    rng(2024);
    u1 = randn(N, 1);
    y = zeros(N, 1);
    for k = 3:N
        y(k) = thetaVerdadeiro(1) * y(k-2) + thetaVerdadeiro(2) * u1(k-1) ...
             + thetaVerdadeiro(3) * y(k-2) * u1(k-1);
    end
    configSeq = configBase;
    configSeq.vars = struct('y', y, 'u1', u1);
    configSeq.usarParfor = false;

    rng(999); % mesmo seed para a parte estocastica do proprio evoluir()
    [modeloSeq, thetaSeq, historicoSeq] = evoluir(configSeq); %#ok<ASGLU>

    % --- execucao com parfor, MESMOS dados e MESMO seed ---
    configPar = configBase;
    configPar.vars = struct('y', y, 'u1', u1);
    configPar.usarParfor = true;

    rng(999); % reseta para o mesmo estado de RNG da execucao sequencial
    [modeloPar, thetaPar, historicoPar] = evoluir(configPar); %#ok<ASGLU>

    % checagem: fitness por geracao deve ser identico entre as duas
    % execucoes (mesmo seed, mesma sequencia de individuos gerados --
    % parfor so muda COMO a avaliacao roda, nao o QUE e avaliado).
    fitnessSeq = [historicoSeq.melhorFitness];
    fitnessPar = [historicoPar.melhorFitness];

    if ~isequal(fitnessSeq, fitnessPar)
        error('test_evoluir_parfor:resultadoDivergente', ...
            ['Fitness por geracao divergiu entre usarParfor=false e true -- ' ...
             'isso indicaria que a paralelizacao alterou o resultado, nao so o tempo.\n' ...
             'sequencial: %s\nparfor:     %s'], ...
            mat2str(fitnessSeq), mat2str(fitnessPar));
    end

    if ~strcmp(modeloSeq.toString(), modeloPar.toString())
        error('test_evoluir_parfor:modeloFinalDivergente', ...
            'Modelo final divergiu entre execucoes sequencial e parfor.');
    end

    fprintf('OK - usarParfor=true produz resultado identico a usarParfor=false (mesmo seed)\n');
end
