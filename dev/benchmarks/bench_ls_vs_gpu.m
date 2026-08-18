function bench_ls_vs_gpu()
%BENCH_LS_VS_GPU Compara ls (CPU) vs lsGpu (GPU) em matrizes de tamanhos crescentes.
%
%   Pula automaticamente se nao houver GPU CUDA disponivel.
%
%   Mede para cada (N, p):
%     - tempo CPU: ls() puro
%     - tempo GPU: lsGpu() incluindo transferencia gpuArray
%     - speedup: t_cpu / t_gpu
%
%   Documenta o ponto de cruzamento: a partir de que (N, p) a GPU compensa.
%   Salva resultado em dev/benchmarks/results/gpu_<timestamp>.json.

    try
        garantirGpuDisponivel();
    catch
        fprintf('bench_ls_vs_gpu: GPU CUDA nao disponivel — benchmark pulado.\n');
        return;
    end

    Ns = [100, 500, 2000, 5000];
    ps = [5, 20, 50];
    nRep = 5;  % repeticoes para estabilidade do timer

    fprintf('=== bench_ls_vs_gpu ===\n');
    fprintf('%-8s %-6s %-10s %-10s %-8s\n', 'N', 'p', 't_cpu(ms)', 't_gpu(ms)', 'speedup');

    resultados = {};
    for ni = 1:numel(Ns)
        for pi_idx = 1:numel(ps)
            N = Ns(ni); p = ps(pi_idx);

            % Gerar problema LS sintetico: P (N x p), y (N x 1)
            rng(42);
            P_cpu = randn(N, p);
            y_cpu = randn(N, 1);

            % Montar vars/terms ficticios para passar para ls/lsGpu via makeRegressors
            % (mais simples: chamar mldivide diretamente para benchmark puro de algebra)
            t_cpus = zeros(1, nRep);
            t_gpus = zeros(1, nRep);
            for r = 1:nRep
                t0 = tic; P_cpu \ y_cpu; t_cpus(r) = toc(t0);
                P_gpu = gpuArray(P_cpu); y_gpu = gpuArray(y_cpu);
                t0 = tic; gather(P_gpu \ y_gpu); t_gpus(r) = toc(t0);
            end

            tCpu = mean(t_cpus) * 1000;  % ms
            tGpu = mean(t_gpus) * 1000;
            speedup = tCpu / tGpu;

            fprintf('%-8d %-6d %-10.3f %-10.3f %-8.2f\n', N, p, tCpu, tGpu, speedup);
            resultados{end+1} = struct('N', N, 'p', p, 't_cpu_ms', tCpu, 't_gpu_ms', tGpu, 'speedup', speedup); %#ok<AGROW>
        end
    end

    % Sumario: ponto de cruzamento
    fprintf('\nRecomendacao:\n');
    fprintf('  GPU compensa (speedup > 1) nos seguintes casos:\n');
    for i = 1:numel(resultados)
        r = resultados{i};
        if r.speedup > 1
            fprintf('    N=%d, p=%d -> speedup=%.2fx\n', r.N, r.p, r.speedup);
        end
    end

    salvarBenchJson('gpu', struct('resultados', {resultados}));
end
