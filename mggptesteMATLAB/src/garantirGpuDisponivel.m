function garantirGpuDisponivel()
%GARANTIRGPUDISPONIVEL Lanca erro claro se nenhuma GPU CUDA utilizavel
%   estiver disponivel, em vez de deixar o MATLAB falhar com uma
%   mensagem generica de "funcao desconhecida" (o que aconteceria se
%   GPUARRAY fosse chamado sem o Parallel Computing Toolbox instalado).
%
%   Chamada no inicio de LSGPU (e de qualquer outra funcao *Gpu futura)
%   para dar um diagnostico acionavel imediatamente, antes de qualquer
%   trabalho ser feito.
%
%   Nao ha fallback automatico para CPU aqui de proposito: se o
%   chamador pediu explicitamente a versao GPU (ex: LSGPU em vez de
%   LS), um fallback silencioso esconderia que a aceleracao esperada
%   nao esta de fato acontecendo — o padrao do projeto (ver nota
%   "usarParfor" em EVOLUIR) e sempre falhar de forma visivel em vez de
%   degradar silenciosamente. Para permitir automaticamente CPU-ou-GPU
%   conforme disponibilidade, o chamador deve decidir isso
%   explicitamente (ex: checar GPUDEVICECOUNT antes de escolher entre
%   LS e LSGPU), nao esperar que esta funcao decida por ele.
%
%   Ver tambem: LSGPU

    % exist(...) sem especificar tipo cobre tanto .m quanto builtin/MEX —
    % mais robusto do que checar um tipo especifico, que pode variar
    % entre versoes do MATLAB para funcoes de toolbox.
    if exist('gpuDeviceCount', 'file') == 0 && exist('gpuDeviceCount', 'builtin') == 0
        error('garantirGpuDisponivel:toolboxAusente', ...
            ['Parallel Computing Toolbox nao encontrado (funcao gpuDeviceCount ' ...
             'indisponivel). Instale o toolbox, ou use a versao CPU (LS em vez ' ...
             'de LSGPU) se GPU nao for necessaria agora.']);
    end

    numGpus = gpuDeviceCount();
    if numGpus == 0
        error('garantirGpuDisponivel:nenhumaGpuEncontrada', ...
            ['Nenhuma GPU CUDA foi encontrada nesta maquina (gpuDeviceCount() = 0). ' ...
             'Use a versao CPU (LS em vez de LSGPU) nesta maquina.']);
    end
end
