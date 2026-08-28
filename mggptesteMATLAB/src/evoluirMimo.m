function [modelos, thetas, historicos] = evoluirMimo(config)
%EVOLUIRMIMO Identificacao MIMO por MGGP: um modelo NARX independente por saida.
%
%   [modelos, thetas, historicos] = EVOLUIRMIMO(config) identifica um
%   modelo MGGP para cada saida listada em config.nomesOutputs, chamando
%   EVOLUIR internamente para cada saida. Durante o treino de cada saida,
%   as demais sao tratadas como entradas (regressores medidos disponiveis),
%   o que e correto para fitness OSA (cada passo usa dados reais).
%
%   Espelha o papel de MGGP(mode='MIMO') da biblioteca Python original
%   (CastroHc/MGGP) — onde cada saida tambem e identificada como um
%   sub-modelo NARX independente, usando as demais saidas como regressores.
%
%   CONVENCAO DE VARS PARA MIMO
%   Em MISO, vars.y e a saida unica. Em MIMO, as saidas ficam em campos
%   separados (ex: vars.y1, vars.y2) e entradas em outros campos (vars.u1,
%   etc.). config.nomesOutputs indica quais campos sao saidas.
%
%   Ao treinar a saida 'y1':
%     - vars.y  = vars.y1 (saida a identificar, campo 'y' exigido por LS)
%     - vars.y2 permanece acessivel como regressor (entrada medida)
%     - nomesEntradas internos = nomesEntradas + {'y2', ...} (outras saidas)
%   Isso e transparente para EVOLUIR: do ponto de vista dele, o problema e
%   sempre MISO com mais entradas disponiveis.
%
%   IMPORTANTE: esta estrategia de treino so e valida para fitness OSA
%   (um-passo-a-frente), onde cada passo usa dados medidos. Free-run
%   acoplado entre saidas deve ser feito via PREDICTFREERUNMIMO.
%
%   ENTRADA
%     config - struct com os mesmos campos de EVOLUIR, mais:
%       nomesOutputs - cell array de strings com os nomes dos campos de
%                      config.vars que sao saidas (ex: {'y1','y2'}).
%                      Cada campo deve existir em config.vars.
%       nomesEntradas - cell array de strings com os nomes das variaveis
%                       de entrada externas (ex: {'u1','u2'}).
%
%   SAIDAS
%     modelos   - cell array {1 x nOut}, o MggpModel de cada saida.
%     thetas    - cell array {1 x nOut}, o theta estimado de cada saida.
%     historicos - cell array {1 x nOut}, o historico de EVOLUIR de cada.
%
%   Ver tambem: EVOLUIR, PREDICTFREERUNMIMO, SCOREOSA

    if ~isfield(config, 'nomesOutputs') || isempty(config.nomesOutputs)
        error('evoluirMimo:nomesOutputsFaltando', ...
            'config.nomesOutputs e obrigatorio (ex: {''y1'',''y2''}).');
    end
    if ~isfield(config, 'vars')
        error('evoluirMimo:varsFaltando', 'config.vars e obrigatorio.');
    end
    if ~isfield(config, 'nomesEntradas')
        error('evoluirMimo:nomesEntradasFaltando', ...
            'config.nomesEntradas e obrigatorio (entradas externas, ex: {''u1'',''u2''}).');
    end

    nomesOutputs = config.nomesOutputs;
    nOut = numel(nomesOutputs);

    for i = 1:nOut
        if ~isfield(config.vars, nomesOutputs{i})
            error('evoluirMimo:outputNaoEncontrado', ...
                'Campo ''%s'' nao encontrado em config.vars.', nomesOutputs{i});
        end
    end

    modelos   = cell(1, nOut);
    thetas    = cell(1, nOut);
    historicos = cell(1, nOut);

    for i = 1:nOut
        nomeSaida = nomesOutputs{i};

        % Outras saidas viram entradas adicionais para este sub-problema
        outrasOutputs = nomesOutputs([1:i-1, i+1:nOut]);

        % vars para este sub-problema: y = esta saida; demais campos mantidos
        varsI = config.vars;
        varsI.y = config.vars.(nomeSaida);

        % nomesEntradas internos = entradas externas + outras saidas
        nomesEntradasI = [config.nomesEntradas(:)', outrasOutputs(:)'];

        % Monta config do sub-problema (copia todos os campos, sobrescreve os especificos)
        cfgI = config;
        cfgI.vars = varsI;
        cfgI.nomesEntradas = nomesEntradasI;
        % Remove campos MIMO para que evoluir nao tente processar nomesOutputs
        if isfield(cfgI, 'nomesOutputs'), cfgI = rmfield(cfgI, 'nomesOutputs'); end

        if isfield(config, 'verbose') && config.verbose
            fprintf('\n=== evoluirMimo: saida %d/%d (%s) ===\n', i, nOut, nomeSaida);
        end

        [modelos{i}, thetas{i}, historicos{i}] = evoluir(cfgI);
    end
end
