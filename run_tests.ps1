# Roda todos os testes via MATLAB em modo batch.
# Uso: .\run_tests.ps1
# Retorna exit code 0 se todos os testes passaram, 1 caso contrário.

$env:MATLAB_BATCH = "1"
matlab -batch "run('run_tests.m')"
exit $LASTEXITCODE
