function print_summary(prefixo)
%PRINT_SUMMARY Le todos os JSONs em dev/benchmarks/results/ e imprime tabela.
%
%   PRINT_SUMMARY()          — todos os arquivos JSON
%   PRINT_SUMMARY('siso')    — apenas arquivos que comecam com 'siso_'
%   PRINT_SUMMARY('perf')    — apenas arquivos que comecam com 'perf_'
%
%   Util para comparar runs diferentes (antes/depois de uma mudanca de codigo).

    if nargin < 1, prefixo = ''; end

    benchDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'benchmarks', 'results');
    if ~isfolder(benchDir)
        fprintf('Diretorio de resultados nao existe: %s\n', benchDir);
        return;
    end

    pattern = fullfile(benchDir, [prefixo '*.json']);
    arquivos = dir(pattern);

    if isempty(arquivos)
        fprintf('Nenhum arquivo JSON encontrado em %s com prefixo "%s"\n', benchDir, prefixo);
        return;
    end

    % Ordenar por data de modificacao (mais recente por ultimo)
    [~, ord] = sort([arquivos.datenum], 'ascend');
    arquivos = arquivos(ord);

    fprintf('=== Resultados de benchmark (%d arquivos) ===\n\n', numel(arquivos));

    for i = 1:numel(arquivos)
        caminho = fullfile(arquivos(i).folder, arquivos(i).name);
        try
            texto = fileread(caminho);
            dados = jsondecode(texto);
        catch ME
            fprintf('[%s] Erro ao ler: %s\n', arquivos(i).name, ME.message);
            continue;
        end

        fprintf('--- %s (%s) ---\n', arquivos(i).name, ...
            datestr(arquivos(i).datenum, 'yyyy-mm-dd HH:MM'));
        imprimirCampos(dados, '  ');
        fprintf('\n');
    end
end

function imprimirCampos(s, indent)
    if isstruct(s)
        campos = fieldnames(s);
        for i = 1:numel(campos)
            c = campos{i};
            v = s.(c);
            if isstruct(v) || iscell(v)
                fprintf('%s%s:\n', indent, c);
                if isstruct(v)
                    imprimirCampos(v, [indent '  ']);
                else
                    for j = 1:numel(v)
                        fprintf('%s  [%d]:\n', indent, j);
                        if isstruct(v{j}), imprimirCampos(v{j}, [indent '    ']); end
                    end
                end
            elseif ischar(v)
                fprintf('%s%s: %s\n', indent, c, v);
            elseif isnumeric(v) && isscalar(v)
                if floor(v) == v
                    fprintf('%s%s: %g\n', indent, c, v);
                else
                    fprintf('%s%s: %.4g\n', indent, c, v);
                end
            elseif isnumeric(v)
                fprintf('%s%s: [%s]\n', indent, c, num2str(v, '%.4g '));
            elseif islogical(v)
                if v, fprintf('%s%s: true\n', indent, c);
                else,  fprintf('%s%s: false\n', indent, c); end
            end
        end
    end
end
