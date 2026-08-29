@echo off
if not exist .venv (
    echo ERRO: .venv nao encontrado. Execute setup.bat primeiro.
    pause
    exit /b 1
)
echo === Iniciando Jupyter Notebook (Python CUDA) ===
echo Abra o arquivo bench_python.ipynb no navegador que abrir.
.venv\Scripts\jupyter notebook bench_python.ipynb
pause
