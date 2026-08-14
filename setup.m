%SETUP Configura o path do MATLAB e verifica as toolboxes necessárias.
%
%   Rodar uma vez por sessão do MATLAB antes de usar qualquer função do projeto:
%       >> setup
%
%   O que faz:
%     1. Adiciona src/ ao path da sessão atual.
%     2. Verifica que o Parallel Computing Toolbox (PCT) está disponível.
%        Sem o PCT, parfor e gpuArray não funcionam — o código sequencial
%        (config.usarParfor = false) ainda funciona normalmente.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'src'));

% Verificar Parallel Computing Toolbox
pctDisponivel = license('test', 'Distrib_Computing_Toolbox');
if ~pctDisponivel
    warning('setup:semPCT', ...
        ['Parallel Computing Toolbox nao encontrado.\n' ...
         '  - config.usarParfor = false  funciona normalmente (sequencial).\n' ...
         '  - config.usarParfor = true   vai lancar erro ao abrir parpool.\n' ...
         '  - lsGpu / garantirGpuDisponivel nao vao funcionar.']);
else
    fprintf('setup: Parallel Computing Toolbox disponivel.\n');
end

fprintf('setup: src/ adicionado ao path. Projeto pronto para uso.\n');
