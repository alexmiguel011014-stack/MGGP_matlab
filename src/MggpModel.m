classdef MggpModel
    %MGGPMODEL Representa um modelo NARX completo: uma colecao de
    %   MggpTerm, com validacao e conversao para o formato de string
    %   que MAKEREGRESSORS/LS/PREDICTFREERUN esperam.
    %
    %   Espelha o papel de mggpElement.createModel + compile_model da
    %   biblioteca Python original — aqui, "compilar" significa apenas
    %   converter a arvore de termos para a lista de strings que o
    %   nucleo numerico ja existente consome, e validar consistencia
    %   (sem termos duplicados, atraso dentro do limite combinado).
    %
    %   Ver tambem: MGGPTERM, MAKEREGRESSORS, LS, PREDICTFREERUN

    properties (SetAccess = immutable)
        termos % array de MggpTerm
    end

    methods
        function obj = MggpModel(termos, maxDelay)
            %MGGPMODEL Constroi um modelo a partir de um array de MggpTerm.
            %
            %   obj = MGGPMODEL(termos) — sem checagem de maxDelay.
            %   obj = MGGPMODEL(termos, maxDelay) — valida que nenhum
            %       termo excede o atraso maximo permitido.
            %
            %   Lanca erro se houver termos duplicados (mesma string
            %   canonica) — um modelo com o mesmo regressor duas vezes
            %   deixaria a matriz de regressores com colunas repetidas,
            %   o que torna P'P singular na maioria dos casos.

            if nargin < 2
                maxDelay = Inf;
            end
            if isempty(termos)
                error('MggpModel:termosVazio', ...
                    'Um modelo precisa de pelo menos um termo.');
            end
            for i = 1:numel(termos)
                if ~isa(termos(i), 'MggpTerm')
                    error('MggpModel:argumentoInvalido', ...
                        'Todos os elementos de termos devem ser MggpTerm.');
                end
            end

            strings = arrayfun(@(t) t.toString(), termos, 'UniformOutput', false);
            if numel(unique(strings)) ~= numel(strings)
                error('MggpModel:termosDuplicados', ...
                    'O modelo tem termos duplicados: %s', strjoin(strings, ', '));
            end

            for i = 1:numel(termos)
                if termos(i).maiorAtraso() > maxDelay
                    error('MggpModel:atrasoExcedeMaxDelay', ...
                        'Termo "%s" usa atraso %d, maior que maxDelay=%d.', ...
                        termos(i).toString(), termos(i).maiorAtraso(), maxDelay);
                end
            end

            obj.termos = termos;
        end

        function strings = compile(obj)
            %COMPILE Converte o modelo para cell array de strings, no
            %   formato exato que MAKEREGRESSORS/LS/PREDICTFREERUN
            %   esperam no argumento 'terms'.
            strings = arrayfun(@(t) t.toString(), obj.termos, 'UniformOutput', false);
        end

        function lag = maiorAtraso(obj)
            %MAIORATRASO Maior atraso entre todos os termos do modelo —
            %   define quantas amostras iniciais de y0 sao necessarias
            %   para PREDICTFREERUN, ou quantas amostras sao descartadas
            %   em MAKEREGRESSORS.
            lag = max(arrayfun(@(t) t.maiorAtraso(), obj.termos));
        end

        function n = numTermos(obj)
            %NUMTERMOS Numero de termos do modelo (= numel(theta) esperado).
            n = numel(obj.termos);
        end

        function [theta, P, yAlinhado] = estimarTheta(obj, vars)
            %ESTIMARTHETA Atalho para a funcao solta LS(vars,
            %   obj.compile()) — estima os parametros do modelo a partir
            %   de dados observados. vars e um struct com o campo 'y'
            %   (saida) e um campo por variavel de entrada usada no
            %   modelo (ver MAKEREGRESSORS).
            %
            %   Nome deliberadamente diferente de 'ls' (a funcao solta em
            %   src/ls.m): um metodo de classdef com o mesmo nome de uma
            %   funcao-arquivo separada e uma fonte conhecida de
            %   ambiguidade de escopo em MATLAB (a chamada interna pode
            %   resolver para o proprio metodo em vez da funcao externa,
            %   dependendo da versao/contexto) — sem MATLAB disponivel
            %   para testar o caso na pratica, o mais seguro e nao correr
            %   esse risco.
            [theta, P, yAlinhado] = ls(vars, obj.compile(), obj.maiorAtraso());
        end

        function y = simularFreeRun(obj, theta, y0, inputs)
            %SIMULARFREERUN Atalho para a funcao solta PREDICTFREERUN
            %   (theta, obj.compile(), y0, inputs) — simula o modelo com
            %   theta dado. inputs e um struct com um campo por variavel
            %   de entrada usada no modelo (ver PREDICTFREERUN).
            %
            %   Nome deliberadamente diferente de 'predictFreeRun' (a
            %   funcao solta em src/predictFreeRun.m) — mesmo motivo de
            %   ESTIMARTHETA acima: evitar qualquer ambiguidade entre
            %   metodo e funcao-arquivo de mesmo nome.
            y = predictFreeRun(theta, obj.compile(), y0, inputs);
        end

        function s = toString(obj)
            %TOSTRING Representacao textual do modelo completo, um termo
            %   por linha (util para inspecao/log).
            linhas = arrayfun(@(t) t.toString(), obj.termos, 'UniformOutput', false);
            s = strjoin(linhas, ' + ');
        end
    end
end
