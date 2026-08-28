"""
bench_python.py — Competicao de bibliotecas MGGP — lado Python.

Parametros fixados conforme configuracao da competicao.
Saida em: ./resultados/

Metricas registradas por modelo:
  Qualidade   : FreeRun RMSE (Vx, Vy) nas 4 trilhas Wang
  Tempo       : tempo_treino_s (wall-clock)
  Custo       : n_avaliacoes (total de individuos avaliados)
  Convergencia: fitness_inicial, fitness_final, geracao_melhor, taxa_melhoria_pct
  Complexidade: n_termos_modelo, max_lag_modelo
"""

import os, sys, time
import numpy as np
import pandas as pd
import dill

# ─── CAMINHOS ─────────────────────────────────────────────────────────────────
_HERE       = os.path.dirname(os.path.abspath(__file__))
DB_DIR      = r"D:\ProjetosPessoais\IC\Database"
RESULTS_DIR = os.path.join(_HERE, "resultados")

os.makedirs(RESULTS_DIR, exist_ok=True)
sys.path.insert(0, _HERE)
from src.mggp import MGGP  # noqa: E402

# ─── PARAMETROS FIXOS DA COMPETICAO ───────────────────────────────────────────
PARAMS = dict(
    nDelays          = [1, 2, 5, 10, 25, 50],
    generations      = 300,
    populationSize   = 300,
    evaluationMode   = "RMSE",
    k                = 300,
    evaluationType   = "MShooting",
    evaluationTypeTest="FreeRun",
    nTerms           = 7,
    maxHeight        = 7,
    mutationRate     = 0.3,
    crossoverRate    = 0.8,
    elitePercentage  = 10,
    mode             = "MIMO",
    froe_mode        = False,
    operators        = ['add', 'subtraction', 'mul'],
)

MAX_TENTATIVAS = 50
META_MODELOS   = 10
RMSE_MIN, RMSE_MAX = 0.0, 100.0

# Colunas do Excel (pandas 0-indexed, conforme notebook original)
U_COLS = [14, 2, 22, 23, 11]
Y_COLS = [18, 17]   # [Vx, Vy]

TRACKS = [
    ("wang21", os.path.join(DB_DIR, "wang21dv_bic_MGGP.xlsx")),  # treino
    ("wang22", os.path.join(DB_DIR, "wang22dv_bic_MGGP.xlsx")),  # validacao
    ("wang31", os.path.join(DB_DIR, "wang31dv_bic_MGGP.xlsx")),  # teste A
    ("wang81", os.path.join(DB_DIR, "wang81dv_bic_MGGP.xlsx")),  # teste B
]


def load_track(path):
    df = pd.read_excel(path, header=0)
    return (df.iloc[:, U_COLS].values.astype(float),
            df.iloc[:, Y_COLS].values.astype(float))


def freerun_rmse(model, y, u):
    """(rmse_vx, rmse_vy) via FreeRun."""
    yp, yd = model.predict("FreeRun", y, u)
    return (float(np.sqrt(np.mean((yd[:, 0] - yp[:, 0]) ** 2))),
            float(np.sqrt(np.mean((yd[:, 1] - yp[:, 1]) ** 2))))


def extract_monitoring(mggp, model, tempo_s):
    """Extrai metricas de monitoramento do logbook DEAP."""
    lb = mggp._logbook
    min_per_gen = lb.chapters['fitness'].select('min')
    avg_per_gen = lb.chapters['fitness'].select('avg')
    gens        = lb.select('gen')
    evals       = lb.select('evals')

    fitness_inicial = float(min_per_gen[0]) if min_per_gen else float('nan')
    fitness_final   = float(min_per_gen[-1]) if min_per_gen else float('nan')
    n_avaliacoes    = int(sum(evals))

    best = fitness_inicial
    geracao_melhor = gens[0] if gens else 1
    for g, f in zip(gens, min_per_gen):
        if np.isfinite(f) and f < best * 0.99:
            best = f
            geracao_melhor = int(g)

    if np.isfinite(fitness_inicial) and fitness_inicial > 0:
        taxa_melhoria = (fitness_inicial - fitness_final) / fitness_inicial * 100
    else:
        taxa_melhoria = float('nan')

    n_termos = int(sum(len(output) for output in model))
    max_lag  = int(model.lagMax) if hasattr(model, 'lagMax') else -1

    conv_df = pd.DataFrame({
        'geracao':        gens,
        'melhor_fitness': min_per_gen,
        'fitness_medio':  avg_per_gen,
    })

    return dict(
        tempo_treino_s    = round(tempo_s, 2),
        n_avaliacoes      = n_avaliacoes,
        fitness_inicial   = round(fitness_inicial, 6),
        fitness_final     = round(fitness_final, 6),
        geracao_melhor    = geracao_melhor,
        taxa_melhoria_pct = round(taxa_melhoria, 2),
        n_termos_modelo   = n_termos,
        max_lag_modelo    = max_lag,
    ), conv_df


def run():
    print(f"[bench_python] nTerms={PARAMS['nTerms']}  maxHeight={PARAMS['maxHeight']}")
    print(f"  nDelays={PARAMS['nDelays']}")
    print(f"  Resultados em: {RESULTS_DIR}\n")

    data = {name: load_track(path) for name, path in TRACKS}
    u_train, y_train = data["wang21"]
    print(f"Treino (Wang 2.1): {y_train.shape[0]} amostras\n")

    results  = []
    n_aceitos = 0

    for tentativa in range(1, MAX_TENTATIVAS + 1):
        if n_aceitos >= META_MODELOS:
            break

        print(f"--- Tentativa {tentativa}  (aceitos: {n_aceitos}/{META_MODELOS}) ---")
        t0 = time.time()
        try:
            mggp = MGGP(inputs=u_train, outputs=y_train, **PARAMS)
            mggp.run()
            tempo_s = time.time() - t0

            model = mggp._hof[0]
            mggp.element.compileModel(model)

            rv, ry = freerun_rmse(model, y_train, u_train)
            rmse_train = (rv + ry) / 2.0
            print(f"  FreeRun treino: Vx={rv:.4f}  Vy={ry:.4f}  mean={rmse_train:.4f}  t={tempo_s:.0f}s")

            if not (RMSE_MIN < rmse_train < RMSE_MAX):
                print("  Rejeitado.")
                continue

            n_aceitos += 1
            mon, conv_df = extract_monitoring(mggp, model, tempo_s)

            row = {
                "library"  : "python",
                "model_id" : n_aceitos,
                "wang21_vx": rv, "wang21_vy": ry,
                "wang22_vx": float('nan'), "wang22_vy": float('nan'),
                "wang31_vx": float('nan'), "wang31_vy": float('nan'),
                "wang81_vx": float('nan'), "wang81_vy": float('nan'),
                **mon,
            }

            for name, (u_t, y_t) in data.items():
                if name == "wang21":
                    continue
                rv2, ry2 = freerun_rmse(model, y_t, u_t)
                row[f"{name}_vx"] = rv2
                row[f"{name}_vy"] = ry2
                print(f"  {name}: Vx={rv2:.4f}  Vy={ry2:.4f}")

            results.append(row)
            print(f"  [OK] Modelo {n_aceitos} | "
                  f"gen_melhor={mon['geracao_melhor']} | "
                  f"evals={mon['n_avaliacoes']} | "
                  f"melhoria={mon['taxa_melhoria_pct']:.1f}%")

            with open(os.path.join(RESULTS_DIR, f"model_py_id{n_aceitos}.pkl"), "wb") as f:
                dill.dump(model, f)
            conv_df.to_csv(
                os.path.join(RESULTS_DIR, f"conv_py_id{n_aceitos}.csv"), index=False
            )

        except Exception as e:
            print(f"  ERRO: {e}")

    print(f"\n{'='*65}")
    print(f"Finalizou: {n_aceitos}/{META_MODELOS} modelos em {tentativa} tentativas.")
    print(f"Taxa de aceitacao: {n_aceitos/tentativa*100:.1f}%")

    if results:
        df_out = pd.DataFrame(results)

        num_cols = [c for c in df_out.columns if c not in ('library', 'model_id')]
        summary = {'library': 'python_MEAN', 'model_id': 0}
        summary.update({c: df_out[c].mean() for c in num_cols})
        df_std = {'library': 'python_STD', 'model_id': 0}
        df_std.update({c: df_out[c].std() for c in num_cols})
        df_out = pd.concat([df_out,
                            pd.DataFrame([summary]),
                            pd.DataFrame([df_std])], ignore_index=True)

        csv_path = os.path.join(RESULTS_DIR, "resultados_python.csv")
        df_out.to_csv(csv_path, index=False)
        print(f"Resultados: {csv_path}")
        print(df_out.to_string())


if __name__ == "__main__":
    run()
