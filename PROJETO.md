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

Feito (passos 1-3 do plano, código escrito e commitado, lógica validada em Python mas
**nunca rodada em MATLAB de verdade ainda**):
- `src/makeRegressors.m` + `src/ls.m` — núcleo numérico (mínimos quadrados).
- `src/predictFreeRun.m` — simulação free-run.
- `src/MggpTerm.m` + `src/MggpModel.m` — representação de árvore/modelo.
- Testes em `dev/tests/`: `test_ls.m`, `test_predictFreeRun.m`, `test_MggpModel.m`.

**Pendência crítica**: nenhum teste foi executado no MATLAB real. Um ponto específico
sinalizado como risco (concatenação de array vazio em `MggpTerm.produto`) só se
confirma rodando. Rodar os 3 testes é pré-requisito de fato antes de confiar no que
foi construído até aqui.

Não feito ainda: passos 4-7 (operadores genéticos, loop evolutivo, paralelismo,
NSGA-II).

## Notas fora do escopo do MGGP em si

Um bug no instalador do `base_project` (`opencode.jsonc` mal formado) foi corrigido
durante essa conversa, e uma proposta de plugins (MATLAB MCP Server + arXiv MCP) ficou
registrada em `dev/plugin-proposals-numerico-cientifico.md` no repositório do
`base_project`.
