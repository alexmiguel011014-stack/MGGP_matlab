# MGGP_Vmatlab — instruções para o assistente

## O que é este projeto
Port nativo em MATLAB puro da biblioteca Python `mggp` (CastroHc/MGGP) — Multi-Gene
Genetic Programming para identificação de sistemas NARX/NARMAX. Nenhuma ponte
Python↔MATLAB; tudo reimplementado do zero.

## Ambiente alvo
- **MATLAB 2025a** (desenvolvido nessa versão; sem preocupação com compatibilidade R2011
  por ora).
- **Parallel Computing Toolbox** (PCT) — necessário para `parfor` e `gpuArray`.
- Sem dependências externas além do MATLAB + PCT.

## Estrutura de diretórios
```
src/          — código de produção (funções e classes MATLAB)
dev/tests/    — testes unitários (um arquivo por módulo)
```

Não criar subdiretórios dentro de `src/` — o projeto é pequeno o suficiente para
um nível plano.

## Convenções de código

### Configuração via struct
Todas as funções principais aceitam um único argumento `config` (struct) com campos
opcionais e defaults explícitos dentro da função. Nunca adicionar parâmetros posicionais
extras — basta adicionar um campo novo ao struct.

### MISO — múltiplas entradas nomeadas
Os dados de entrada chegam como struct com campo `y` (saída) + campos com o nome de cada
variável de entrada (ex: `vars.u1`, `vars.u2`). Não assumir nomes fixos `u`/`x`.

### Paralelismo
- **CPU**: flag `config.usarParfor` em `evoluir.m` — ativa `parfor` na avaliação de
  fitness. Exige PCT; MATLAB lança erro claro sem fallback silencioso.
- **GPU**: `src/lsGpu.m` + `src/garantirGpuDisponivel.m` — operacional em isolamento
  mas **não integrado** ao loop evolutivo ainda. Motivo: GPU só compensa processando
  toda a população em lote numa única operação de álgebra; integração exige
  reestruturar `avaliarPopulacao` para vetorização em lote — trabalho pendente.

### Padrão de testes
- Cada arquivo `dev/tests/test_X.m` define uma função `test_X()` sem argumentos.
- Sucesso = a função termina sem `error()`; imprime `"OK ..."` no final.
- Falha = `error(...)` com ID no formato `'test_X:razao'`.
- Não usar `assert()` avulso — usar `error()` com mensagem clara.
- `test_lsGpu.m` pula (aviso) se não houver GPU CUDA disponível na máquina.

## Status atual (importante)
**Nenhum dos 8 testes rodou no MATLAB real ainda.** Toda a validação foi lógica e
revisão manual. Antes de qualquer mudança estrutural, rodar os testes na ordem:
`test_ls → test_predictFreeRun → test_MggpModel → test_operadoresGeneticos →
test_evoluir → test_evoluir_parfor → test_lsGpu → test_evoluirNsga2`.
Erros iniciais (ex: `makeRegressors`) podem se manifestar como falhas confusas nas
camadas superiores.

## NSGA-II
`src/evoluirNsga2.m` e os auxiliares de Pareto (`dominanciaParento.m`,
`ordenacaoNaoDominada.m`, `distanciaAglomeracao.m`) são uma **extensão**, sem
equivalente no projeto Python original. Objetivos: erro OSA × número de termos.

## Referências
- [CastroHc/MGGP](https://github.com/CastroHc/MGGP) — biblioteca Python original
- [rafael-veiga/MGGP-CUDA](https://github.com/rafael-veiga/MGGP-CUDA) — arquitetura GPU anterior do grupo
- GPTIPS (Searson) — toolbox MATLAB de referência para GP simbólica
