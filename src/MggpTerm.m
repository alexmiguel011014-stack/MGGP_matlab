classdef MggpTerm
    %MGGPTERM Representa um unico termo de um modelo NARX (SISO ou MISO)
    %   como estrutura, nao como string solta.
    %
    %   Um termo e um produto de um ou mais fatores. Cada fator e uma
    %   variavel nomeada (ex: 'y', 'u1', 'h1' — qualquer nome, exceto o
    %   reservado 'const') com um atraso associado (0 = sem atraso), ou
    %   o fator especial 'const' (termo constante, sempre vale 1).
    %
    %   Exemplo: o termo 'q2(y)*q1(u1)' (y(k-2)*u1(k-1)) e representado
    %   como MggpTerm com dois fatores:
    %       fatores(1) = struct('variavel','y','atraso',2)
    %       fatores(2) = struct('variavel','u1','atraso',1)
    %
    %   Espelha o papel dos "terms" (lista de strings) usados em
    %   mggpElement.createModel da biblioteca Python original — aqui
    %   como estrutura, para o motor de GP poder montar/inspecionar/
    %   recombinar termos programaticamente em vez de manipular texto.
    %   'y' e sempre a saida do sistema (mesma convencao de 'ARG0' na
    %   biblioteca original); qualquer outro nome e uma variavel de
    %   entrada (permite MISO: varias entradas nomeadas livremente).
    %
    %   Ver tambem: MGGPMODEL

    properties (SetAccess = immutable)
        fatores % array de struct('variavel', char, 'atraso', double)
    end

    methods
        function obj = MggpTerm(fatores)
            %MGGPTERM Constroi um termo a partir de um array de fatores.
            %
            %   obj = MGGPTERM(fatores) — fatores e um array de struct
            %   com campos 'variavel' (nome livre, ou 'const') e
            %   'atraso' (inteiro >= 0; deve ser 0 se variavel='const').
            %
            %   Use os construtores de conveniencia MGGPTERM.CONST,
            %   MGGPTERM.VAR e MGGPTERM.PRODUTO em vez de chamar este
            %   construtor bruto diretamente, na maioria dos casos.

            if nargin == 0
                error('MggpTerm:argumentoObrigatorio', ...
                    'MggpTerm precisa de pelo menos um fator.');
            end
            if isempty(fatores)
                error('MggpTerm:fatoresVazio', ...
                    'Um termo precisa de pelo menos um fator.');
            end
            for i = 1:numel(fatores)
                f = fatores(i);
                if isempty(f.variavel) || ~ischar(f.variavel)
                    error('MggpTerm:variavelInvalida', ...
                        'Nome de variavel invalido — deve ser uma string nao-vazia.');
                end
                if strcmp(f.variavel, 'const') && f.atraso ~= 0
                    error('MggpTerm:constComAtraso', ...
                        'O fator ''const'' nao pode ter atraso diferente de 0.');
                end
                if f.atraso < 0
                    error('MggpTerm:atrasoNegativo', ...
                        'Atraso nao pode ser negativo (recebido: %d).', f.atraso);
                end
            end
            obj.fatores = fatores;
        end

        function lag = maiorAtraso(obj)
            %MAIORATRASO Retorna o maior atraso entre os fatores do termo.
            lag = max([obj.fatores.atraso]);
        end

        function nomes = variaveisUsadas(obj)
            %VARIAVEISUSADAS Cell array com os nomes de variavel distintos
            %   usados neste termo (exclui 'const'). Util para o motor de
            %   GP saber, ao recombinar termos, quais variaveis de
            %   entrada estao disponiveis num dado problema.
            todosNomes = {obj.fatores.variavel};
            nomes = unique(todosNomes(~strcmp(todosNomes, 'const')));
        end

        function s = toString(obj)
            %TOSTRING Representacao textual do termo, no mesmo formato
            %   de string aceito por MAKEREGRESSORS/PREDICTFREERUN — a
            %   estrutura e a fonte de verdade, a string e derivada dela,
            %   nunca o contrario (evita as duas ficarem dessincronizadas).
            partes = cell(1, numel(obj.fatores));
            for i = 1:numel(obj.fatores)
                f = obj.fatores(i);
                if strcmp(f.variavel, 'const')
                    partes{i} = '1';
                elseif f.atraso == 0
                    partes{i} = f.variavel;
                else
                    partes{i} = sprintf('q%d(%s)', f.atraso, f.variavel);
                end
            end
            s = strjoin(partes, '*');
        end
    end

    methods (Static)
        function t = const()
            %CONST Cria o termo constante (equivalente a '1').
            t = MggpTerm(struct('variavel', 'const', 'atraso', 0));
        end

        function t = var(variavel, atraso)
            %VAR Cria um termo de fator unico: variavel com atraso dado.
            %   Ex: MggpTerm.var('y', 2) equivale a 'q2(y)'.
            %       MggpTerm.var('u1', 0) equivale a 'u1' (sem atraso).
            if nargin < 2
                atraso = 0;
            end
            t = MggpTerm(struct('variavel', variavel, 'atraso', atraso));
        end

        function t = produto(varargin)
            %PRODUTO Cria um termo como produto de varios MggpTerm de
            %   fator unico. Ex:
            %       MggpTerm.produto(MggpTerm.var('y',2), MggpTerm.var('u1',1))
            %   equivale a 'q2(y)*q1(u1)'.
            todosFatores = [];
            for i = 1:numel(varargin)
                termo = varargin{i};
                if ~isa(termo, 'MggpTerm')
                    error('MggpTerm:argumentoInvalido', ...
                        'produto() espera argumentos MggpTerm.');
                end
                todosFatores = [todosFatores, termo.fatores]; %#ok<AGROW>
            end
            t = MggpTerm(todosFatores);
        end
    end
end
