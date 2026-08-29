@echo off
echo === Configurando ambiente Python MGGP CUDA ===
echo.
echo NOTA: Requer CUDA Toolkit instalado. Verifique a versao com:
echo   nvcc --version
echo.
echo Para CUDA 12.x: usa requirements.txt (cupy-cuda12x)
echo Para CUDA 11.x: use: pip install -r requirements_cuda11.txt
echo.
if exist .venv (
    echo Ambiente .venv ja existe.
) else (
    python -m venv .venv
)
.venv\Scripts\pip install --upgrade pip -q
.venv\Scripts\pip install -r requirements.txt
echo.
echo === Verificando CuPy / GPU ===
.venv\Scripts\python -c "import cupy as cp; n=cp.cuda.runtime.getDeviceCount(); print(f'{n} GPU(s) CUDA encontrada(s)'); [print(f'  GPU {i}: {cp.cuda.runtime.getDeviceProperties(i)[\"name\"].decode()}') for i in range(n)]" 2>nul || echo [AVISO] CuPy nao instalado ou GPU nao disponivel — pacote roda em modo CPU-fallback.
echo.
echo === Setup concluido ===
pause
