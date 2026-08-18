function salvarBenchJson(nome, dados)
%SALVARBENCHJSON Salva resultado de benchmark em dev/benchmarks/results/<nome>_<ts>.json.
%
%   Campos automaticos adicionados:
%     timestamp     — ISO 8601
%     matlabVersion — versao do MATLAB em uso
%     hostname      — nome da maquina

    ts = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH-mm-ss'));
    try
        host = char(java.net.InetAddress.getLocalHost().getHostName());
    catch
        host = 'desconhecido';
    end

    envelope = struct('timestamp', ts, 'matlabVersion', version(), ...
        'hostname', host, 'dados', dados);

    benchDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'benchmarks', 'results');
    if ~isfolder(benchDir)
        mkdir(benchDir);
    end

    arquivo = fullfile(benchDir, sprintf('%s_%s.json', nome, ts));
    fid = fopen(arquivo, 'w');
    if fid == -1
        warning('salvarBenchJson:erroAbrirArquivo', 'Nao foi possivel abrir: %s', arquivo);
        return;
    end
    fprintf(fid, '%s', jsonencode(envelope));
    fclose(fid);

    fprintf('Resultado salvo em: %s\n', arquivo);
end
