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

### MIMO — múltiplas saídas
- **`evoluirMimo.m`**: wrapper que itera sobre `config.nomesOutputs = {'y1','y2',...}`,
  chama `evoluir` para cada saída. Cada sub-problema vê `vars.y = vars.(yi)` e as demais
  saídas como regressores adicionais em `nomesEntradas`. Válido para fitness OSA (usa dados
  medidos em cada passo). `config.nomesEntradas` deve conter apenas entradas **externas**.
- **`predictFreeRunMimo.m`**: free-run acoplado — simula todas as saídas simultaneamente
  passo a passo, usando valores já simulados de saídas anteriores como regressores.
  `'y'` num termo de modelo `i` resolve para a coluna `i` de `Ys`; o nome de outra saída
  (ex: `'y2'`) resolve para a coluna correspondente.
- **Convenção de nomes nos termos MIMO**: ao treinar saída `y1`, termos `q1(y)` referenciam
  `y1`; termos `q1(y2)` referenciam a saída `y2` medida. Durante free-run, ambas são
  simuladas. Nunca renomear `y` para o nome da saída nos termos — a distinção é feita
  pelo contexto de `evoluirMimo`/`predictFreeRunMimo`.

### Paralelismo
- **CPU**: flag `config.usarParfor` em `evoluir.m` — ativa `parfor` na avaliação de
  fitness. Exige PCT; MATLAB lança erro claro sem fallback silencioso.
- **GPU**: `src/lsGpu.m` + `src/garantirGpuDisponivel.m` — operacional em isolamento
  mas **não integrado** ao loop evolutivo ainda. Motivo: GPU só compensa processando
  toda a população em lote numa única operação de álgebra; integração exige
  reestruturar `avaliarPopulacao` para vetorização em lote — trabalho pendente.

### Fitness disponíveis (`config.tipoFitness`)
- `'osa'` (default): erro OSA — `scoreOsa.m`. Mais rápido, numericamente estável.
- `'mShooting'`: janelas de free-run — `scoreMShooting.m`. Penaliza modelos instáveis;
  alinhado com o default da biblioteca Python. Controle via `config.janelaMShooting` (default 5).

### Defaults de `evoluir.m` (alinhados com a biblioteca Python)
| campo | default | Python original |
|---|---|---|
| `popSize` | 100 | 100 |
| `nGeracoes` | 50 | 50 |
| `cxpb` | 0.8 | `crossoverRate=0.8` |
| `mtpb` | 0.1 | (implícito) |
| `tamanhoTorneio` | 2 | `tournsize=2` |
| `elite` | 0.10 | `elitePercentage=10%` |
| `maxDelay` | 5 | obrigatório no Python |
| `numTermosInicial` | 5 | `n_genes=5` |
| `tipoFitness` | `'mShooting'` | `evaluationType='MShooting'` |
| `janelaMShooting` | 5 | `windowSize` dinâmico (ver G4-A4) |

### Limitações de paridade conhecidas (não corrigíveis sem redesign)
Diferenças estruturais entre MATLAB e Python que **não devem ser "corrigidas"** — registradas
aqui para evitar confusão ao comparar resultados:

- **G4-A1 — offset de lag**: Python `q_i` ≈ MATLAB `q_{i+1}`. Um atraso `q1` no Python
  equivale a `q2` no MATLAB; os modelos são funcionalmente equivalentes mas os expoentes
  diferem por 1.
- **G4-A2 — profundidade de árvore vs. produtos planos**: Python usa árvores DEAP com
  profundidade e não-linearidades embutidas (e.g., `sin`, `exp`); MATLAB usa produtos planos
  de fatores lineares. Os espaços de hipóteses são diferentes.
- **G4-A3 — operadores de crossover/mutação**: Python usa `CrossHighUniform +
  CrossLowUniform` e `MutGPOneTree + MutGPUniform + MutGPReplace`; MATLAB usa operadores
  próprios (`crossoverTermos`, `mutarModelo`). A dinâmica evolutiva difere.
- **G4-A4 — janela MShooting dinâmica vs. fixa**: Python usa `windowSize = lagMax+1+k`
  calculado por amostra; MATLAB usa `k=janelaMShooting` fixo (default 5). O número de
  janelas e amostras avaliadas diferem para séries longas.

### Padrão de testes
- Cada arquivo `dev/tests/test_X.m` define uma função `test_X()` sem argumentos.
- Sucesso = a função termina sem `error()`; imprime `"OK ..."` no final.
- Falha = `error(...)` com ID no formato `'test_X:razao'`.
- Não usar `assert()` avulso — usar `error()` com mensagem clara.
- `test_lsGpu.m` pula (aviso) se não houver GPU CUDA disponível na máquina.

## Status atual (importante)
**Suite completa precisa ser re-rodada**: mudanças G4-1 (bias em `makeRegressors`),
G4-2 (windowing MShooting), G4-3 (defaults) alteram a interface; todos os 10 testes
precisam ser validados no MATLAB R2025b antes de considerar a suite estável novamente.
Suite completa: `run_tests` (10 testes). Ordem de dependência:
`test_ls → test_predictFreeRun → test_MggpModel → test_operadoresGeneticos →
test_evoluir → test_evoluir_parfor → test_lsGpu → test_evoluirNsga2 →
test_scoreMShooting → test_evoluirMimo`.
Erros em camadas inferiores propagam como falhas confusas nas superiores.

## NSGA-II
`src/evoluirNsga2.m` e os auxiliares de Pareto (`dominanciaParento.m`,
`ordenacaoNaoDominada.m`, `distanciaAglomeracao.m`) são uma **extensão**, sem
equivalente no projeto Python original. Objetivos: erro OSA × número de termos.

## Referências
- [CastroHc/MGGP](https://github.com/CastroHc/MGGP) — biblioteca Python original
- [rafael-veiga/MGGP-CUDA](https://github.com/rafael-veiga/MGGP-CUDA) — arquitetura GPU anterior do grupo
- GPTIPS (Searson) — toolbox MATLAB de referência para GP simbólica
