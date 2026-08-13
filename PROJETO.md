# MGGP em MATLAB — projeto

## Objetivo

Portar nativamente a biblioteca `mggp` (Python, NARX/NARMAX via Multi-Gene Genetic
Programming) para MATLAB puro, para entregar o projeto pronto ao professor.

## Decisões-chave

- **Port nativo, não ponte Python↔MATLAB** — decisão do professor, provavelmente por
  causa do gargalo de paralelização do DEAP (`creator` não serializa bem entre
  processos).
- `numpy` não é o problema — MATLAB já cobre isso nativamente. O trabalho real é
  reconstruir o motor de GP (árvores, crossover, mutação, seleção) que hoje vem do
  DEAP, sem equivalente pronto em MATLAB.
- **Ambiente**: desenvolvendo no MATLAB 2025a; a universidade tem R2011, mas decidido
  por ora não se preocupar com compatibilidade 2011.
- **Paralelismo CPU+GPU é meta real** (replicar o projeto CUDA anterior do grupo), via
  `parfor`/`gpuArray` — só depois que a versão sequencial estiver correta.
- Git local, sem remoto por enquanto.

## Referências para consultar durante a construção

- [CastroHc/MGGP](https://github.com/CastroHc/MGGP) — biblioteca Python original a
  portar.
- [rafael-veiga/MGGP-CUDA](https://github.com/rafael-veiga/MGGP-CUDA) — arquitetura
  CPU+GPU anterior do grupo.
- GPTIPS (Searson) — toolbox MATLAB de MGGP já existente, paralelismo só CPU,
  referência de arquitetura.

## Plano de construção (ordem)

1. Núcleo numérico
2. Harness de validação contra a Python original
3. Representação de árvore/avaliador
4. Operadores genéticos
5. Loop evolutivo completo
6. Paralelismo (`parfor` depois `gpuArray`)
7. NSGA-II (opcional)

## Status

Feito (passos 1-4 do plano, código escrito e commitado, lógica validada em Python mas
**nunca rodada em MATLAB de verdade ainda**):
- `src/makeRegressors.m` + `src/ls.m` — núcleo numérico (mínimos quadrados), **MISO**
  (número arbitrário de variáveis de entrada nomeadas, não só `y`/`u` fixos).
- `src/predictFreeRun.m` — simulação free-run, também MISO.
- `src/MggpTerm.m` + `src/MggpModel.m` — representação de árvore/modelo, MISO.
- `src/gerarIndividuoAleatorio.m` — geração de indivíduo inicial válido.
- `src/crossoverTermos.m` + `src/crossoverModelos.m` — crossover de 1 ponto entre
  fatores de dois termos-pai (subtree), aplicado a nível de modelo.
- `src/mutarTermo.m` + `src/mutarModelo.m` — mutação (trocar/adicionar/remover fator).
- Testes em `dev/tests/`: `test_ls.m`, `test_predictFreeRun.m`, `test_MggpModel.m`,
  `test_operadoresGeneticos.m`.

**Pendência crítica**: nenhum teste foi executado no MATLAB real ainda. Rodar os 4
testes é pré-requisito antes de confiar no que foi construído até aqui — a
generalização para MISO reescreveu código já commitado que também nunca rodou.

Não feito ainda: passos 5-7 (loop evolutivo completo, paralelismo `parfor`/`gpuArray`,
NSGA-II opcional).

## Notas fora do escopo do MGGP em si

Um bug no instalador do `base_project` (`opencode.jsonc` mal formado) foi corrigido
durante essa conversa, e uma proposta de plugins (MATLAB MCP Server + arXiv MCP) ficou
registrada em `dev/plugin-proposals-numerico-cientifico.md` no repositório do
`base_project`.
