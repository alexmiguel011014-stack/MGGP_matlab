%RUN_LINT Roda checkcode (mlint) em todos os arquivos de src/ e reporta avisos.
%
%   Uso:
%       >> run_lint
%
%   Sai com aviso se encontrar problemas; não lança erro (checkcode é
%   informativo, não um gate de build por padrão).

srcDir = fullfile(fileparts(mfilename('fullpath')), 'src');
files = dir(fullfile(srcDir, '*.m'));

totalProblemas = 0;
for i = 1:numel(files)
    caminho = fullfile(srcDir, files(i).name);
    info = checkcode(caminho, '-struct');
    if ~isempty(info)
        fprintf('%s:\n', files(i).name);
        for j = 1:numel(info)
            if isfield(info(j), 'id')
                fprintf('  linha %d: [%s] %s\n', info(j).line, info(j).id, info(j).message);
            else
                fprintf('  linha %d: %s\n', info(j).line, info(j).message);
            end
        end
        totalProblemas = totalProblemas + numel(info);
    end
end

if totalProblemas == 0
    fprintf('OK: nenhum aviso de checkcode em src/ (%d arquivos).\n', numel(files));
else
    fprintf('\nTotal: %d aviso(s) em %d arquivo(s).\n', totalProblemas, numel(files));
end
