function test_lsGpu()
%TEST_LSGPU Valida lsGpu contra o mesmo sistema de referencia de test_ls.m.
%
%   IMPORTANTE: este teste so roda de fato se uma GPU CUDA estiver
%   disponivel nesta maquina. Se nao estiver, o teste avisa e retorna
%   sem erro (SKIP), em vez de falhar — a ausencia de GPU nao e uma
%   falha deste codigo, e o restante da suite de testes (CPU) continua
%   validando a logica normalmente. Isto e diferente de
%   GARANTIRGPUDISPONIVEL (chamada dentro de LSGPU), que lanca erro se
%   alguem tentar usar LSGPU sem GPU — aqui, no teste, o objetivo e
%   nao quebrar a suite inteira em uma maquina sem GPU.
%
%   Criterio: theta estimado por LSGPU deve bater com theta estimado
%   por LS (CPU) para os MESMOS dados — a GPU deve produzir o mesmo
%   resultado numerico (dentro de uma tolerancia um pouco mais frouxa
%   que os testes CPU-only, porque mldivide na GPU pode ter
%   comportamento numerico ligeiramente diferente — ver nota sobre
%   precisao no cabecalho de LSGPU e a fonte MathWorks citada la).
%
%   Rodar: >> test_lsGpu
%   Sucesso (com GPU): imprime "OK" e nao lanca erro.
%   Sucesso (sem GPU): imprime aviso de SKIP e nao lanca erro.

    temGpu = false;
    if exist('gpuDeviceCount', 'file') ~= 0 || exist('gpuDeviceCount', 'builtin') ~= 0
        try
            temGpu = gpuDeviceCount() > 0;
        catch
            temGpu = false;
        end
    end

    if ~temGpu
        fprintf('SKIP - nenhuma GPU CUDA disponivel nesta maquina, test_lsGpu nao executado.\n');
        return;
    end

    rng(42);

    N = 500;
    % bias=0 explícito (theta tem nTerms+1 elementos pós G4-1)
    thetaVerdadeiro = [0; 0.75; 0.25; -0.20];
    terms = {'q2(y)', 'q1(u)', 'q2(y)*q1(u)'};

    u = randn(N, 1);
    y = zeros(N, 1);
    for k = 3:N
        y(k) = thetaVerdadeiro(2) * y(k-2) ...
             + thetaVerdadeiro(3) * u(k-1) ...
             + thetaVerdadeiro(4) * y(k-2) * u(k-1);
    end

    vars = struct('y', y, 'u', u);

    thetaCpu = ls(vars, terms);
    thetaGpuResultado = lsGpu(vars, terms);

    erroVsVerdadeiro = abs(thetaGpuResultado - thetaVerdadeiro);
    erroVsCpu = abs(thetaGpuResultado - thetaCpu);

    tolerancia = 1e-6; % mais frouxa que os 1e-8 dos testes CPU-only, ver nota no cabecalho

    if any(erroVsVerdadeiro > tolerancia)
        error('test_lsGpu:erroVsVerdadeiro', ...
            'lsGpu nao recuperou theta esperado (erro max: %.2e).', max(erroVsVerdadeiro));
    end
    if any(erroVsCpu > tolerancia)
        error('test_lsGpu:erroVsCpu', ...
            'lsGpu divergiu de ls (CPU) alem da tolerancia (erro max: %.2e).', max(erroVsCpu));
    end

    fprintf('OK - lsGpu bateu com ls (CPU) e com theta verdadeiro (erro max: %.2e)\n', ...
        max([erroVsVerdadeiro; erroVsCpu]));
end
