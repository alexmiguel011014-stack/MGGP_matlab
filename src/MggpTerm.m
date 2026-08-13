classdef MggpTerm
    %MGGPTERM Representa um unico termo de um modelo NARX como estrutura,
    %   nao como string solta.
    %
    %   Um termo e um produto de um ou mais fatores. Cada fator e uma
    %   variavel ('y' ou 'u') com um atraso associado (0 = sem atraso),
    %   ou o fator especial 'const' (termo constante, sempre vale 1).
    %
    %   Exemplo: o termo 'q2(y)*q1(u)' (y(k-2)*u(k-1)) e representado
    %   como MggpTerm com dois fatores:
    %       fatores(1) = struct('variavel','y','atraso',2)
    %       fatores(2) = struct('variavel','u','atraso',1)
    %
    %   Espelha o papel dos "terms" (lista de strings) usados em
    %   mggpElement.createModel da biblioteca Python original — aqui
    %   como estrutura, para o motor de GP poder montar/inspecionar
    %   termos programaticamente em vez de manipular texto.
    %
    %   Ver tambem: MGGPMODEL

    properties (SetAccess = immutable)
        fatores % array de struct('variavel', 'y'|'u'|'const', 'atraso', double)
    end

    methods
        function obj = MggpTerm(fatores)
            %MGGPTERM Constroi um termo a partir de um array de fatores.
            %
            %   obj = MGGPTERM(fatores) — fatores e um array de struct
            %   com campos 'variavel' ('y', 'u' ou 'const') e 'atraso'
            %   (inteiro >= 0; ignorado/deve ser 0 se variavel='const').
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
                if ~ismember(f.variavel, {'y', 'u', 'const'})
                    error('MggpTerm:variavelInvalida', ...
                        'Variavel "%s" invalida — use ''y'', ''u'' ou ''const''.', f.variavel);
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
            %       MggpTerm.var('u', 0) equivale a 'u' (sem atraso).
            if nargin < 2
                atraso = 0;
            end
            t = MggpTerm(struct('variavel', variavel, 'atraso', atraso));
        end

        function t = produto(varargin)
            %PRODUTO Cria um termo como produto de varios MggpTerm de
            %   fator unico. Ex:
            %       MggpTerm.produto(MggpTerm.var('y',2), MggpTerm.var('u',1))
            %   equivale a 'q2(y)*q1(u)'.
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
