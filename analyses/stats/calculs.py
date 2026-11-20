from dataclasses import dataclass

from scipy.stats import beta, chi2, chisquare


@dataclass
class Taux:
    nombre: int
    exposition: float
    par: float
    valeur: float
    bas: float
    haut: float


# Intervalle exact de Garwood pour un comptage de Poisson
def intervalle_poisson(n, niveau=0.95):
    a = 1 - niveau
    bas = 0.0 if n == 0 else chi2.ppf(a / 2, 2 * n) / 2
    haut = chi2.ppf(1 - a / 2, 2 * (n + 1)) / 2
    return bas, haut


def taux(n, exposition, par, niveau=0.95):
    if exposition <= 0:
        raise ValueError("exposition nulle ou négative")
    bas, haut = intervalle_poisson(n, niveau)
    return Taux(n, exposition, par, n / exposition * par, bas / exposition * par, haut / exposition * par)


# Intervalle exact de Clopper-Pearson pour une proportion k / n
def proportion(k, n, niveau=0.95):
    if n == 0:
        return None, None, None
    a = 1 - niveau
    bas = 0.0 if k == 0 else beta.ppf(a / 2, k, n - k + 1)
    haut = 1.0 if k == n else beta.ppf(1 - a / 2, k + 1, n - k)
    return k / n, bas, haut


# Rapport de deux taux de Poisson, intervalle exact conditionnel (via la binomiale)
def rapport_de_taux(n1, e1, n2, e2, niveau=0.95):
    if n2 == 0:
        return None, None, None
    _, p_bas, p_haut = proportion(n1, n1 + n2, niveau)
    facteur = e2 / e1
    haut = float("inf") if p_haut == 1 else p_haut / (1 - p_haut) * facteur
    return (n1 / e1) / (n2 / e2), p_bas / (1 - p_bas) * facteur, haut


# Test du khi-deux : les comptages suivent-ils les poids attendus (ex. nombre de jours du mois) ?
def ecart_au_hasard(comptes, poids):
    total = sum(comptes)
    attendus = [total * p / sum(poids) for p in poids]
    resultat = chisquare(comptes, attendus)
    return float(resultat.statistic), float(resultat.pvalue)
