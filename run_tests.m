%RUN_TESTS Roda todos os testes do projeto e sai com código 1 se qualquer um falhar.
%
%   Para usar interativamente no MATLAB:
%       >> run_tests
%
%   Para usar na linha de comando (PowerShell / bash):
%       matlab -batch "run('run_tests.m')"
%   Ou via wrapper:
%       ./run_tests.ps1       (Windows)
%       ./run_tests.sh        (Linux/macOS)
%
%   Ordem dos testes: das camadas mais baixas para as mais altas, para que
%   uma falha precoce aponte para a camada correta em vez de produzir erros
%   confusos nas camadas superiores.

setup;  % garante que src/ está no path

tests = {
    'dev/tests/test_ls'
    'dev/tests/test_predictFreeRun'
    'dev/tests/test_MggpModel'
    'dev/tests/test_operadoresGeneticos'
    'dev/tests/test_evoluir'
    'dev/tests/test_evoluir_parfor'
    'dev/tests/test_lsGpu'
    'dev/tests/test_evoluirNsga2'
    'dev/tests/test_scoreMShooting'
    'dev/tests/test_evoluirMimo'
};

falhas = 0;
for i = 1:numel(tests)
    testFile = tests{i};
    [~, testName] = fileparts(testFile);
    fprintf('\n[%d/%d] %s ...\n', i, numel(tests), testName);
    try
        run(testFile);
    catch ME
        fprintf('  FALHOU: %s\n', ME.message);
        falhas = falhas + 1;
    end
end

fprintf('\n--- %d/%d testes passaram ---\n', numel(tests) - falhas, numel(tests));

if falhas > 0
    fprintf('FALHA: %d teste(s) falharam.\n', falhas);
    if ~isempty(getenv('MATLAB_BATCH'))
        exit(1);
    end
else
    fprintf('OK: todos os testes passaram.\n');
end
