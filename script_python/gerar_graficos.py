"""
Gera os graficos do trabalho de amostragem (substitui os PROC SGPLOT do SAS).

Le a mesma base (intencoes_de_voto_pavilhoes.xlsx), replica a limpeza e as
regras de negocio ja implementadas em script_sas/trabalho_amostragem.sas
(strip() em Samara Martins, grupo "Outros" <1% dos votos validos, formula
de Cochran com divisor n-1 e IC via t-Student) e salva os PNGs em imagens/.

Paleta de cores validada com o script validate_palette.js da skill dataviz
(CVD-safe para as cores "de candidato"; os tons de cinza para Branco/Nulo/
Sem resposta/Nao sei sao propositalmente de baixo croma - a identificacao
deles nao depende de cor, ja que a legenda sempre traz o rotulo em texto).
"""
import re
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import pandas as pd
from scipy import stats

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_PATH = BASE_DIR / "intenções_de_voto_pavilhões.xlsx"
OUT_DIR = BASE_DIR / "imagens"
OUT_DIR.mkdir(exist_ok=True)

N_DF = 2_562_037  # TRE-DF, julho/2026 - usado so para registro, fpc desprezivel

plt.rcParams.update({
    "font.size": 10,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "axes.grid.axis": "y",
    "grid.alpha": 0.3,
    "figure.dpi": 150,
})

# ---------------------------------------------------------------------------
# 1-2. LEITURA E LIMPEZA (replica Secoes 1-2 do trabalho_amostragem.sas)
# ---------------------------------------------------------------------------
df = pd.read_excel(DATA_PATH)
df = df.rename(columns={
    "Sexo": "sexo",
    "Faixa etária": "faixa_etaria",
    "Faixa de renda familiar": "faixa_renda",
    "Presidente": "presidente",
    "Governador": "governador",
    "Turno": "turno",
})
df = df[df["Timestamp"].notna()].reset_index(drop=True)


def limpar_nome(nome):
    """Remove espacos nas pontas e o sufixo numerico entre parenteses usado
    no instrumento de coleta como codigo interno do candidato (ex.: 'Luiz
    Inácio Lula da Silva (5)' -> 'Luiz Inácio Lula da Silva'), para não
    confundir a leitura dos gráficos."""
    if pd.isna(nome):
        return nome
    return re.sub(r"\s*\(\d+\)\s*$", "", str(nome).strip())


df["presidente"] = df["presidente"].apply(limpar_nome)
df["governador"] = df["governador"].apply(limpar_nome)

n_nominal = len(df)

TURNO_ORDER = ["Manhã", "Tarde", "Noite"]
RENDA_ORDER = ["Sem resposta", "até R$ 1.000", "R$ 1.000 a R$ 2.000",
               "R$ 2.000 a R$ 5.000", "R$ 5.000 a R$ 10.000", "Mais de R$ 10.000"]
ETARIA_ORDER = ["Sem resposta", "até 18 anos", "19 a 24 anos", "25 a 29 anos",
                "30 a 34 anos", "35 a 39 anos", "40 a 44 anos", "Acima de 44 anos"]

df["turno"] = pd.Categorical(df["turno"], categories=TURNO_ORDER, ordered=True)
df["faixa_renda"] = pd.Categorical(df["faixa_renda"], categories=RENDA_ORDER, ordered=True)
df["faixa_etaria"] = pd.Categorical(df["faixa_etaria"], categories=ETARIA_ORDER, ordered=True)

# ---------------------------------------------------------------------------
# 3. GRUPO "OUTROS" (<1% dos votos validos) - replica Secao 6.5 do .sas
#    Exatamente como no SAS: Branco/Nulo/Sem resposta/Nao sei NUNCA entram em
#    "Outros", mesmo que (hipoteticamente) ficassem abaixo de 1%.
# ---------------------------------------------------------------------------
NAO_VOTO_PRES = {"Branco", "Nulo", "Não sei/não quero responder", "Sem resposta"}
NAO_VOTO_GOV = {"Branco", "Nulo", "Não sei / Não quero responder", "Sem resposta"}


def agrupar_outros(serie: pd.Series, excluidos: set) -> pd.Series:
    contagem = serie.value_counts()  # ja ignora NaN
    n_valido = contagem.sum()

    def mapear(v):
        if pd.isna(v) or v in excluidos:
            return v
        return "Outros" if (contagem[v] / n_valido) < 0.01 else v

    return serie.map(mapear)


df["presidente_grp"] = agrupar_outros(df["presidente"], NAO_VOTO_PRES)
df["governador_grp"] = agrupar_outros(df["governador"], NAO_VOTO_GOV)

n_valid_pres = df["presidente"].notna().sum()
n_valid_gov = df["governador"].notna().sum()

# ---------------------------------------------------------------------------
# 4. ESTIMATIVAS E IC 95% (replica Secao 6/6.6 do .sas: Cochran com n-1 e
#    percentil t de Student, nao Z fixo)
# ---------------------------------------------------------------------------
def estimar_ic(serie: pd.Series, conf: float = 0.95) -> pd.DataFrame:
    contagem = serie.value_counts()
    n = int(contagem.sum())
    tcrit = stats.t.ppf(1 - (1 - conf) / 2, df=n - 1)
    linhas = []
    for categoria, count in contagem.items():
        p_hat = count / n
        var_p = p_hat * (1 - p_hat) / (n - 1)
        se_p = var_p ** 0.5
        me = tcrit * se_p
        linhas.append({
            "categoria": categoria,
            "count": int(count),
            "pct": p_hat * 100,
            "li_pct": max(0.0, (p_hat - me) * 100),
            "ls_pct": min(100.0, (p_hat + me) * 100),
        })
    return pd.DataFrame(linhas).sort_values("pct", ascending=False).reset_index(drop=True)


# ---------------------------------------------------------------------------
# 5. PALETA DE CORES E ORDEM DA LEGENDA (replica Secao 6.7 do .sas, com a
#    ordem da legenda invertida a pedido: candidatos em ordem alfabetica
#    primeiro, "Outros" em seguida, e o bloco de nao-voto (Branco/Nulo/Sem
#    resposta/Nao sei) por ultimo).
#    Validada com scripts/validate_palette.js da skill dataviz (CVD-safe
#    entre as cores "de candidato"; Cappelli trocou de verde puro para um
#    verde-azulado para nao colidir com o laranja do Kiko sob protanopia -
#    unica mudanca de cor em relacao ao attrmap do SAS).
# ---------------------------------------------------------------------------
PALETA_PRES = {
    "Augusto Cury": "#2CA02C",
    "Flavio Bolsonaro": "#1F6FD1",
    "Luiz Inácio Lula da Silva": "#E03C31",
    "Renan Santos": "#D4AC0D",
    "Ronaldo Caiado": "#9467BD",
    "Samara Martins": "#8B4513",
    "Outros": "#C2A878",
    "Branco": "#BFBFBF",
    "Nulo": "#808080",
    "Sem resposta": "#595959",
    "Não sei/não quero responder": "#404040",
}
PALETA_GOV = {
    "Celina Leão": "#D4AC0D",
    "Kiko Caputo": "#E8821E",
    "Leandro Grass": "#E03C31",
    "Paula Belmonte": "#1F6FD1",
    "Ricardo Cappelli": "#1B998B",
    "Outros": "#C2A878",
    "Branco": "#BFBFBF",
    "Nulo": "#808080",
    "Sem resposta": "#595959",
    "Não sei / Não quero responder": "#404040",
}
ORDEM_PRES = list(PALETA_PRES.keys())
ORDEM_GOV = list(PALETA_GOV.keys())

COR_NEUTRA = "#3B6FA0"  # usada nos graficos de perfil (serie unica, sem significado de identidade)


# ---------------------------------------------------------------------------
# FUNCOES DE PLOTAGEM
# ---------------------------------------------------------------------------
def escapar(texto: str) -> str:
    """Evita que o matplotlib interprete '$' como início de modo matemático
    (sem isso, 'R$ 1.000 a R$ 2.000' é renderizado como 'R1.000aR 2.000')."""
    return str(texto).replace("$", r"\$")


def salvar(fig, nome):
    path = OUT_DIR / f"{nome}.png"
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)
    print(f"  salvo: {path.relative_to(BASE_DIR)}")


def grafico_perfil(serie: pd.Series, titulo: str, xlabel: str, nome: str, rotacionar=False):
    contagem = serie.value_counts(dropna=True)
    if isinstance(serie.dtype, pd.CategoricalDtype):
        contagem = contagem.reindex(serie.cat.categories)
    pct = contagem / contagem.sum() * 100

    fig, ax = plt.subplots(figsize=(7, 4.5))
    rotulos = [escapar(c) for c in pct.index.astype(str)]
    bars = ax.bar(rotulos, pct.values, color=COR_NEUTRA,
                   edgecolor="white", linewidth=0.5, width=0.65)
    for bar, v in zip(bars, pct.values):
        ax.annotate(f"{v:.1f}%", (bar.get_x() + bar.get_width() / 2, bar.get_height()),
                    textcoords="offset points", xytext=(0, 3), ha="center", fontsize=9)
    ax.set_title(titulo, fontsize=12, fontweight="bold")
    ax.set_ylabel("Percentual (%)")
    ax.set_xlabel(xlabel)
    ax.yaxis.set_major_formatter(mticker.PercentFormatter(decimals=0))
    ax.set_ylim(0, max(pct.values) * 1.2)
    if rotacionar:
        plt.setp(ax.get_xticklabels(), rotation=35, ha="right")
    salvar(fig, nome)


def grafico_ic(serie: pd.Series, paleta: dict, titulo: str, nome: str):
    ic = estimar_ic(serie)
    ic = ic.sort_values("pct", ascending=True).reset_index(drop=True)  # maior no topo do hbar
    cores = [paleta.get(c, "#AAAAAA") for c in ic["categoria"]]

    fig, ax = plt.subplots(figsize=(8, 0.5 * len(ic) + 1.5))
    y = np.arange(len(ic))
    ax.barh(y, ic["pct"], color=cores, edgecolor="white", linewidth=0.5, height=0.65)
    erro_inf = (ic["pct"] - ic["li_pct"]).clip(lower=0)
    erro_sup = (ic["ls_pct"] - ic["pct"]).clip(lower=0)
    ax.errorbar(ic["pct"], y, xerr=[erro_inf, erro_sup], fmt="none",
                ecolor="black", elinewidth=1.5, capsize=3)
    for yi, v, ls in zip(y, ic["pct"], ic["ls_pct"]):
        ax.annotate(f"{v:.1f}%", (ls, yi), textcoords="offset points", xytext=(6, 0),
                    va="center", fontsize=9)
    ax.set_yticks(y)
    ax.set_yticklabels([escapar(c) for c in ic["categoria"]])
    ax.set_xlabel("Percentual (%)")
    ax.set_title(f"{titulo}\nCandidatos com menos de 1% dos votos agrupados em 'Outros'",
                 fontsize=11, fontweight="bold")
    ax.xaxis.set_major_formatter(mticker.PercentFormatter(decimals=0))
    ax.set_xlim(0, max(ic["ls_pct"]) * 1.22)
    salvar(fig, nome)


def grafico_empilhado(cat_col: str, grp_col: str, paleta: dict, ordem: list,
                       titulo: str, xlabel: str, nome: str, rotacionar=False):
    tab = pd.crosstab(df[cat_col], df[grp_col], normalize="index") * 100
    tab = tab.reindex(columns=[c for c in ordem if c in tab.columns])
    if isinstance(df[cat_col].dtype, pd.CategoricalDtype):
        tab = tab.reindex(df[cat_col].cat.categories)

    fig, ax = plt.subplots(figsize=(8.5, 5.5))
    bottom = np.zeros(len(tab))
    x = np.arange(len(tab))
    for grp in tab.columns:
        vals = tab[grp].values
        ax.bar(x, vals, bottom=bottom, color=paleta.get(grp, "#AAAAAA"),
               edgecolor="white", linewidth=0.5, width=0.65, label=grp)
        bottom += vals
    ax.set_xticks(x)
    ax.set_xticklabels([escapar(c) for c in tab.index], rotation=35 if rotacionar else 0,
                        ha="right" if rotacionar else "center")
    ax.set_ylabel(f"Percentual dentro de cada categoria (%)")
    ax.set_xlabel(xlabel)
    ax.set_title(f"{titulo}\nCandidatos com menos de 1% dos votos agrupados em 'Outros'",
                 fontsize=11, fontweight="bold")
    ax.yaxis.set_major_formatter(mticker.PercentFormatter(decimals=0))
    ax.set_ylim(0, 100)
    ax.legend(title="Voto", bbox_to_anchor=(1.02, 1), loc="upper left",
              fontsize=8, title_fontsize=9, frameon=False)
    salvar(fig, nome)


# ---------------------------------------------------------------------------
# EXECUCAO
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    print(f"n nominal: {n_nominal} | n valido Presidente: {n_valid_pres} | "
          f"n valido Governador: {n_valid_gov}")
    print("Gerando graficos de perfil...")
    grafico_perfil(df["sexo"], "Distribuição por Sexo", "Sexo", "perfil_sexo")
    grafico_perfil(df["faixa_etaria"], "Distribuição por Faixa Etária", "Faixa etária",
                   "perfil_etaria", rotacionar=True)
    grafico_perfil(df["faixa_renda"], "Distribuição por Faixa de Renda Familiar",
                   "Faixa de renda", "perfil_renda", rotacionar=True)
    grafico_perfil(df["turno"], "Distribuição por Turno de Coleta", "Turno", "perfil_turno")

    print("Gerando graficos de intenção de voto (IC 95%)...")
    grafico_ic(df["presidente_grp"], PALETA_PRES,
               "Intenção de voto - Presidente (%) com IC 95%", "voto_presidente_ic")
    grafico_ic(df["governador_grp"], PALETA_GOV,
               "Intenção de voto - Governador (%) com IC 95%", "voto_governador_ic")

    print("Gerando graficos por subgrupo...")
    grafico_empilhado("faixa_renda", "presidente_grp", PALETA_PRES, ORDEM_PRES,
                       "Presidente por Faixa de Renda (% dentro de cada faixa)",
                       "Faixa de renda", "presidente_por_renda", rotacionar=True)
    grafico_empilhado("faixa_etaria", "presidente_grp", PALETA_PRES, ORDEM_PRES,
                       "Presidente por Faixa Etária (% dentro de cada faixa)",
                       "Faixa etária", "presidente_por_etaria", rotacionar=True)
    grafico_empilhado("turno", "presidente_grp", PALETA_PRES, ORDEM_PRES,
                       "Presidente por Turno (% dentro de cada turno)",
                       "Turno", "presidente_por_turno")
    grafico_empilhado("faixa_renda", "governador_grp", PALETA_GOV, ORDEM_GOV,
                       "Governador por Faixa de Renda (% dentro de cada faixa)",
                       "Faixa de renda", "governador_por_renda", rotacionar=True)
    grafico_empilhado("faixa_etaria", "governador_grp", PALETA_GOV, ORDEM_GOV,
                       "Governador por Faixa Etária (% dentro de cada faixa)",
                       "Faixa etária", "governador_por_etaria", rotacionar=True)
    grafico_empilhado("turno", "governador_grp", PALETA_GOV, ORDEM_GOV,
                       "Governador por Turno (% dentro de cada turno)",
                       "Turno", "governador_por_turno")

    print("Concluído.")
