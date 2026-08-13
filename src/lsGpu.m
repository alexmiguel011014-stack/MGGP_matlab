function [theta, P, yAlinhado] = lsGpu(vars, terms, maxDelay)
%LSGPU Estima os parametros de um modelo NARX via minimos quadrados na GPU.
%
%   [theta, P, yAlinhado] = LSGPU(vars, terms, maxDelay) monta a matriz
%   de regressores em CPU (via MAKEREGRESSORS — a logica de parsing dos
%   termos nao e reescrita aqui, so o passo de resolucao do sistema
%   linear roda na GPU), converte para gpuArray, resolve theta = P\y na
%   GPU (mldivide roda na GPU automaticamente quando o input e
%   gpuArray — nao ha uma funcao "gpu mldivide" separada, e o MESMO
%   operador \, so que o tipo do dado decide onde a computacao ocorre),
%   e traz o resultado de volta para CPU via GATHER antes de retornar.
%
%   Por que so o mldivide vai para GPU, nao a montagem de P: montar P
%   e trabalho de indexacao/string-parsing (MAKEREGRESSORS), que a GPU
%   nao acelera bem (overhead de transferencia por elemento pequeno
%   superaria o ganho); resolver o sistema linear e algebra densa, onde
%   a GPU realmente ajuda para matrizes/populacoes grandes.
%
%   REQUISITO: GPU CUDA disponivel e Parallel Computing Toolbox
%   instalado. Se gpuDevice() falhar (sem GPU, driver ausente, etc.),
%   esta funcao deixa o erro nativo do MATLAB se propagar — sem
%   fallback automatico e silencioso para CPU (ver GARANTIRGPUDISPONIVEL).
%   Para uso com fallback automatico, chame LS diretamente em vez desta
%   funcao quando nao houver GPU.
%
%   ENTRADAS/SAIDAS: identicas a LS (ver LS) — yAlinhado e theta
%   retornados como arrays normais de CPU (double), nao gpuArray,
%   porque o restante do pipeline (MggpModel, avaliarFitness etc.) opera
%   em CPU; o chamador nao precisa saber que a resolucao passou pela GPU.
%
%   Ver tambem: LS, MAKEREGRESSORS, GARANTIRGPUDISPONIVEL

    if nargin < 3
        maxDelay = Inf;
    end

    garantirGpuDisponivel();

    P = makeRegressors(vars, terms, maxDelay);

    y = vars.y(:);
    numAmostrasValidas = size(P, 1);
    yAlinhado = y((end - numAmostrasValidas + 1):end);

    Pgpu = gpuArray(P);
    yGpu = gpuArray(yAlinhado);

    thetaGpu = Pgpu \ yGpu;

    theta = gather(thetaGpu);
end
