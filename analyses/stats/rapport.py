import calendar
from datetime import date
from pathlib import Path

from matplotlib.figure import Figure

from stats import donnees
from stats.calculs import ecart_au_hasard, intervalle_poisson, proportion, rapport_de_taux, taux

MODES = {"road": "Routier", "air": "Aérien", "rail": "Ferroviaire", "maritime": "Maritime"}
COULEURS = {"road": "#e8900c", "air": "#2f7cf6", "rail": "#0e9f6e", "maritime": "#7c4ddb"}
JOURS = ["lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."]
MOIS = ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

# Chiffres publiés ailleurs, pour vérifier que nos calculs retombent sur les mêmes ordres de grandeur
REFERENCES = {
    "route_metropole": {
        "tues": (5.2, "ONISR, « La sécurité routière en France, bilan de l'année 2023 », septembre 2024, p. 10"),
    },
    "aviation_generale_us": {
        "accidents": (3.86, "AOPA Air Safety Institute, McSpadden Report (données 2023), novembre 2025"),
        "mortels": (0.65, "AOPA Air Safety Institute, McSpadden Report (données 2023), novembre 2025"),
    },
}


def nombre(x, decimales=0):
    texte = f"{x:,.{decimales}f}".replace(",", " ").replace(".", ",")
    return texte


def pourcent(x):
    return f"{nombre(100 * x, 1)} %"


def valeur_p(p):
    return f"{p:.2g}".replace(".", ",")


def tableau(entetes, lignes):
    sortie = ["| " + " | ".join(entetes) + " |", "|" + "---|" * len(entetes)]
    sortie += ["| " + " | ".join(str(c) for c in ligne) + " |" for ligne in lignes]
    return "\n".join(sortie)


def style(ax):
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(axis="y", color="#e2e7f0")
    ax.set_axisbelow(True)


def figure_saisons(mois, annee, dossier):
    fig = Figure(figsize=(8, 3.6))
    ax = fig.subplots()
    jours = [calendar.monthrange(annee, m)[1] for m in range(1, 13)]
    for mode in sorted({m["mode"] for m in mois}):
        comptes = {m["mois"]: m["accidents"] for m in mois if m["mode"] == mode}
        par_jour = [comptes.get(m, 0) / jours[m - 1] for m in range(1, 13)]
        moyenne = sum(comptes.values()) / sum(jours)
        ax.plot(range(1, 13), [v / moyenne for v in par_jour], marker="o", color=COULEURS[mode], label=MODES[mode])
    ax.axhline(1, color="#566074", linewidth=0.8, linestyle="--")
    ax.set_xticks(range(1, 13), MOIS)
    ax.set_ylabel("indice (1 = moyenne)")
    ax.set_title(f"Accidents par jour selon le mois, {annee}", loc="left")
    ax.legend(frameon=False)
    style(ax)
    fig.tight_layout()
    fig.savefig(dossier / "saisons.png", dpi=150)


def figure_jours(jours, annee, dossier):
    fig = Figure(figsize=(8, 3.4))
    ax = fig.subplots()
    modes = sorted({j["mode"] for j in jours})
    largeur = 0.8 / len(modes)
    for i, mode in enumerate(modes):
        comptes = {j["jour"]: j["accidents"] for j in jours if j["mode"] == mode}
        total = sum(comptes.values())
        x = [j + (i - (len(modes) - 1) / 2) * largeur for j in range(1, 8)]
        ax.bar(x, [comptes.get(j, 0) / total for j in range(1, 8)], width=largeur, color=COULEURS[mode],
               label=MODES[mode])
    ax.axhline(1 / 7, color="#566074", linewidth=0.8, linestyle="--")
    ax.set_xticks(range(1, 8), JOURS)
    ax.yaxis.set_major_formatter(lambda v, _: pourcent(v))
    ax.set_title(f"Part des accidents selon le jour de la semaine, {annee}", loc="left")
    ax.legend(frameon=False)
    style(ax)
    fig.tight_layout()
    fig.savefig(dossier / "jours.png", dpi=150)


def figure_letalite(modes, annee, dossier):
    fig = Figure(figsize=(8, 2.6))
    ax = fig.subplots()
    for i, m in enumerate(modes):
        bas, haut = intervalle_poisson(m["tues"])
        valeur = 100 * m["tues"] / m["accidents"]
        ax.errorbar(valeur, i, xerr=[[valeur - 100 * bas / m["accidents"]], [100 * haut / m["accidents"] - valeur]],
                    fmt="o", color=COULEURS[m["mode"]], capsize=4)
        ax.annotate(nombre(valeur, 1), (valeur, i), xytext=(0, 8), textcoords="offset points", ha="center")
    ax.set_yticks(range(len(modes)), [MODES[m["mode"]] for m in modes])
    ax.set_ylim(-0.6, len(modes) - 0.4)
    ax.set_xlim(left=0)
    ax.set_xlabel("tués pour 100 accidents (intervalle de confiance à 95 %)")
    ax.set_title(f"Gravité moyenne d'un accident, {annee}", loc="left")
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout()
    fig.savefig(dossier / "letalite.png", dpi=150)


def section_taux(conn, annee, dossier):
    texte = ["## 4. Taux rapportés à l'exposition", ""]
    lignes, absents = [], []
    for cle, p in donnees.PERIMETRES.items():
        n = donnees.numerateur(conn, annee, cle)
        e = donnees.exposition(conn, annee, cle)
        if e is None:
            absents.append(f"- {p['titre']} : **dénominateur d'exposition absent, taux non calculé.**")
            continue
        if n["accidents"] == 0:
            absents.append(f"- {p['titre']} : aucun accident importé pour {annee}, taux non calculé.")
            continue
        for libelle, champ in [("accidents", "accidents"), ("accidents mortels", "mortels"), ("tués", "tues")]:
            t = taux(n[champ], float(e["value"]), p["par"])
            reference = REFERENCES.get(cle, {}).get(champ)
            lignes.append([p["titre"], f"{libelle} {p['unite']}", nombre(n[champ]), nombre(t.valeur, 2),
                           f"{nombre(t.bas, 2)} – {nombre(t.haut, 2)}",
                           f"{nombre(reference[0], 2)} ({reference[1]})" if reference else "—"])
        texte.append(f"- {p['titre']} : exposition de {nombre(float(e['value']))} {e['unit_note']}.")
    if lignes:
        texte += ["", tableau(["Périmètre", "Indicateur", "Nombre", "Taux", "IC 95 %", "Chiffre publié"], lignes)]
    texte += absents
    texte += ["", "Les intervalles sont exacts (loi de Poisson, méthode de Garwood). Ils mesurent l'aléa du "
              "comptage, pas l'incertitude du dénominateur, qui est une estimation (sondage pour la FAA, "
              "modèle de circulation pour le SDES). Les écarts avec les chiffres publiés viennent surtout des "
              "périmètres : par exemple, le rapport AOPA ne retient pas exactement les mêmes vols que nous.", ""]
    texte += section_evolution(conn, dossier)
    return texte


# Toutes les années qui ont à la fois des accidents importés et un dénominateur
def section_evolution(conn, dossier):
    series = {}
    for cle, p in donnees.PERIMETRES.items():
        points = []
        for an in donnees.annees_exposees(conn, cle):
            n = donnees.numerateur(conn, an, cle)
            if n["accidents"]:
                e = donnees.exposition(conn, an, cle)
                points.append((an, taux(n["mortels"], float(e["value"]), p["par"])))
        if len(points) >= 2:
            series[cle] = points
    if not series:
        return ["Une seule année exploitable par périmètre : pas encore d'évolution à montrer. Importer d'autres "
                "années (BAAC, NTSB) suffit, les dénominateurs 2015-2023 sont déjà chargés.", ""]

    fig = Figure(figsize=(8, 3.2 * len(series)))
    axes = fig.subplots(len(series), 1, squeeze=False)[:, 0]
    texte = ["### Évolution des accidents mortels rapportés à l'exposition", ""]
    for ax, (cle, points) in zip(axes, series.items(), strict=True):
        p = donnees.PERIMETRES[cle]
        annees = [a for a, _ in points]
        valeurs = [t.valeur for _, t in points]
        ax.fill_between(annees, [t.bas for _, t in points], [t.haut for _, t in points], color=COULEURS[p["mode"]],
                        alpha=0.18, linewidth=0)
        ax.plot(annees, valeurs, marker="o", color=COULEURS[p["mode"]])
        ax.set_title(f"{p['titre']} : accidents mortels {p['unite']}", loc="left")
        ax.set_xticks(annees)
        ax.set_ylim(bottom=0)
        style(ax)
        texte += [tableau(["Année", "Accidents mortels", f"Taux {p['unite']}", "IC 95 %"],
                          [[a, nombre(t.nombre), nombre(t.valeur, 2), f"{nombre(t.bas, 2)} – {nombre(t.haut, 2)}"]
                           for a, t in points]), ""]
        premier, dernier = points[0][1], points[-1][1]
        rr, bas, haut = rapport_de_taux(dernier.nombre, dernier.exposition, premier.nombre, premier.exposition)
        texte += [f"Rapport des taux {points[-1][0]} / {points[0][0]} : {nombre(rr, 2)} "
                  f"(IC 95 % {nombre(bas, 2)} – {nombre(haut, 2)}). "
                  + ("L'intervalle contient 1 : pas de baisse ni de hausse démontrée."
                     if bas <= 1 <= haut else "L'intervalle exclut 1 : l'écart dépasse l'aléa du comptage."), ""]
    fig.tight_layout()
    fig.savefig(dossier / "evolution.png", dpi=150)
    texte += ["![Évolution](evolution.png)", "",
              "La zone colorée est l'intervalle de confiance à 95 %. 2020 est une année à part (confinements).", ""]
    return texte


def produire(annee, dossier):
    dossier = Path(dossier)
    dossier.mkdir(parents=True, exist_ok=True)
    with donnees.connexion() as conn:
        modes = donnees.par_mode(conn, annee)
        mois = donnees.par_mois(conn, annee)
        jours = donnees.par_jour(conn, annee)
        sources = donnees.sources(conn, annee)
        hors = donnees.hors_perimetre(conn, annee)
        taux_texte = section_taux(conn, annee, dossier)

    if not modes:
        raise SystemExit(f"Aucun accident validé en {annee} : rien à analyser.")

    figure_saisons(mois, annee, dossier)
    figure_jours(jours, annee, dossier)
    figure_letalite(modes, annee, dossier)

    r = [f"# Statistiques des accidents {annee}", "",
         f"Rapport produit le {date.today():%d/%m/%Y} par `python -m stats {annee}`, à partir des accidents "
         "**validés et réels** de la base (les données simulées et non vérifiées sont exclues).", "",
         "## 1. Sources", "",
         tableau(["Source", "Licence", "Accidents"], [[s["source"], s["licence"], nombre(s["accidents"])] for s in sources]),
         "", "## 2. Vue d'ensemble", ""]

    lignes = []
    for m in modes:
        p, bas, haut = proportion(m["mortels"], m["accidents"])
        lignes.append([MODES[m["mode"]], nombre(m["accidents"]), nombre(m["mortels"]),
                       f"{pourcent(p)} ({pourcent(bas)} – {pourcent(haut)})", nombre(m["tues"]),
                       nombre(100 * m["tues"] / m["accidents"], 1), nombre(m["graves"])])
    r += [tableau(["Mode", "Accidents", "Mortels", "Part mortelle (IC 95 %)", "Tués", "Tués / 100 acc.",
                   "Blessés graves"], lignes), "",
          "![Gravité moyenne](letalite.png)", "",
          "Ces nombres ne disent **pas** quel mode est le plus dangereux : les définitions diffèrent (voir §5) "
          "et rien n'est encore rapporté au trafic. La part d'accidents mortels est bien plus forte en aérien "
          "parce qu'un accident NTSB se définit par des dommages importants à l'appareil ou une blessure grave, "
          "alors qu'un accident BAAC est tout accident corporel, souvent léger.",
          "", "## 3. Quand ont lieu les accidents ?", "", "![Saisons](saisons.png)", ""]

    jours_mois = [calendar.monthrange(annee, x)[1] for x in range(1, 13)]
    tests = []
    for mode in sorted({m["mode"] for m in mois}):
        comptes = {x["mois"]: x["accidents"] for x in mois if x["mode"] == mode}
        stat, pv = ecart_au_hasard([comptes.get(x, 0) for x in range(1, 13)], jours_mois)
        par_j = {x["jour"]: x["accidents"] for x in jours if x["mode"] == mode}
        stat_j, pv_j = ecart_au_hasard([par_j.get(x, 0) for x in range(1, 8)], [1] * 7)
        tests.append([MODES[mode], f"{nombre(stat, 1)} (p = {valeur_p(pv)})", f"{nombre(stat_j, 1)} (p = {valeur_p(pv_j)})"])
    r += ["![Jours](jours.png)", "",
          "Test du khi-deux : la répartition s'écarte-t-elle d'un hasard uniforme (à nombre de jours égal) ?", "",
          tableau(["Mode", "Mois (11 ddl)", "Jour de la semaine (6 ddl)"], tests), "",
          "Une petite valeur de p dit seulement que la répartition n'est pas uniforme. Elle ne dit pas pourquoi : "
          "le trafic lui-même varie selon la saison et le jour (vacances, météo favorable aux vols de loisir).", ""]

    r += taux_texte

    r += ["## 5. Biais et limites", "",
          f"- **Périmètres.** Les taux routiers portent sur la France métropolitaine : {nombre(hors['route_outre_mer'])} "
          f"accidents et {nombre(hors['tues_outre_mer'])} tués d'outre-mer sont exclus, faute de trafic estimé. "
          f"En aérien, {nombre(hors['air_hors_us'])} accidents hors États-Unis et {nombre(hors['air_us_hors_ag'])} "
          "vols commerciaux réguliers (parties 121 et 129) sont exclus du taux d'aviation générale.",
          "- **Définitions.** Un « blessé grave » BAAC est hospitalisé plus de 24 h ; un « serious injury » NTSB "
          "suit une autre définition (hospitalisation de plus de 48 h, fractures…). Un tué est compté à 30 jours "
          "dans les deux sources. Les comparaisons entre modes ne sont donc valables que sur les tués.",
          "- **Sous-déclaration.** Le BAAC ne recense que les accidents corporels constatés par les forces de "
          "l'ordre ; les accidents matériels et une partie des blessés légers manquent.",
          "- **Dénominateurs.** Le trafic routier est une estimation (provisoire l'année suivante) ; les heures "
          "de vol FAA viennent d'un sondage avec sa propre marge d'erreur.",
          "- **Données manquantes.** "
          + ", ".join(f"{MODES[m['mode']]} : {nombre(m['gravite_inconnue'])} gravités inconnues" for m in modes) + ".",
          "- **Tués d'un même accident.** Ils ne sont pas indépendants (un car, un avion de quatre places) : "
          "l'intervalle de Poisson sur les tués est donc un peu trop étroit. Celui sur les accidents ne l'est pas.",
          "- **Causalité.** Ce rapport décrit ; il n'établit aucune cause. Un écart entre deux groupes peut venir "
          "d'un facteur non mesuré (trafic, météo, type de véhicule).", ""]

    (dossier / "rapport.md").write_text("\n".join(r), encoding="utf-8")
    return dossier / "rapport.md"
