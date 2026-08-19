# MGGP em MATLAB

Port nativo em MATLAB puro da biblioteca Python [`mggp`](https://github.com/CastroHc/MGGP)
— identificação de sistemas NARX/NARMAX via Multi-Gene Genetic Programming (MGGP).

## Pré-requisitos

- **MATLAB 2025a** (desenvolvido nessa versão)
- **Parallel Computing Toolbox** (PCT) — necessário para `parfor` e `gpuArray`

Sem o PCT, o modo sequencial (`config.usarParfor = false`) funciona normalmente.

## Como rodar

```matlab
% 1. No MATLAB, na raiz do projeto:
setup       % adiciona src/ ao path e verifica toolboxes

% 2. Rodar todos os testes:
run_tests
```

Ou pela linha de comando (PowerShell):

```powershell
.\run_tests.ps1
```

## Estrutura

```
src/             Código de produção
  makeRegressors.m   Montagem da matriz de regressores (MISO)
  ls.m               Mínimos quadrados
  predictFreeRun.m   Simulação free-run NARX
  MggpTerm.m         Representação de um termo (árvore de fatores)
  MggpModel.m        Modelo multi-gene (conjunto de termos + theta)
  gerarIndividuoAleatorio.m  Geração aleatória de indivíduos
  crossoverTermos.m / crossoverModelos.m   Crossover subtree
  mutarTermo.m / mutarModelo.m             Mutação
  scoreOsa.m         Fitness one-step-ahead (padrão)
  scoreMShooting.m   Fitness por janelas de free-run (alinhado ao Python original)
  evoluir.m          Loop evolutivo principal (torneio, elitismo, parfor)
  lsGpu.m            Mínimos quadrados via gpuArray
  garantirGpuDisponivel.m   Verificação de GPU CUDA
  evoluirNsga2.m     Loop NSGA-II (extensão — erro OSA × nº de termos)
  dominanciaParento.m / ordenacaoNaoDominada.m / distanciaAglomeracao.m

dev/tests/       Testes unitários (um por módulo, mesma ordem de dependência)
```

### Modo de fitness

Por padrão `evoluir` usa fitness OSA. Para ativar o modo MShooting (janelas de free-run, mais exigente — padrão da biblioteca Python):

```matlab
config.tipoFitness    = 'mShooting';  % 'osa' (default) | 'mShooting'
config.janelaMShooting = 5;           % tamanho da janela em amostras (default 5)
```

## Referências

- [CastroHc/MGGP](https://github.com/CastroHc/MGGP) — biblioteca Python original portada
- [rafael-veiga/MGGP-CUDA](https://github.com/rafael-veiga/MGGP-CUDA) — arquitetura CPU+GPU anterior do grupo
- GPTIPS (Searson) — toolbox MATLAB de referência para GP simbólica
