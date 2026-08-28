@echo off
echo === Configurando ambiente Python MGGP ===

if exist .venv (
    echo Ambiente .venv ja existe. Pulando criacao.
) else (
    echo Criando .venv...
    python -m venv .venv
    if errorlevel 1 (
        echo ERRO: falha ao criar .venv. Verifique se Python esta no PATH.
        pause
        exit /b 1
    )
)

echo Instalando dependencias...
.venv\Scripts\pip install --upgrade pip -q
.venv\Scripts\pip install -r requirements.txt

if errorlevel 1 (
    echo ERRO: falha ao instalar dependencias.
    pause
    exit /b 1
)

echo.
echo === Ambiente pronto! Execute run.bat para iniciar o benchmark. ===
pause
