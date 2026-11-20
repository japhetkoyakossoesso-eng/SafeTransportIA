import math

import pytest

from stats.calculs import ecart_au_hasard, intervalle_poisson, proportion, rapport_de_taux, taux


def test_poisson_valeurs_de_reference():
    # valeurs des tables de Garwood (1936)
    assert intervalle_poisson(0) == pytest.approx((0, 3.689), abs=1e-3)
    assert intervalle_poisson(10) == pytest.approx((4.795, 18.390), abs=1e-3)


def test_taux_par_milliard():
    t = taux(3167, 609e9, 1e9)
    assert t.valeur == pytest.approx(5.2, abs=0.01)
    assert t.bas < t.valeur < t.haut
    assert t.haut - t.bas < 0.4


def test_exposition_nulle_refusee():
    with pytest.raises(ValueError):
        taux(3, 0, 1e5)


def test_proportion_clopper_pearson():
    p, bas, haut = proportion(5, 10)
    assert p == 0.5
    assert bas == pytest.approx(0.1871, abs=1e-4)
    assert haut == pytest.approx(0.8129, abs=1e-4)
    assert proportion(0, 0) == (None, None, None)


def test_rapport_de_taux_egaux():
    rr, bas, haut = rapport_de_taux(100, 1e6, 100, 1e6)
    assert rr == 1
    assert bas < 1 < haut


def test_rapport_de_taux_sans_reference():
    assert rapport_de_taux(3, 1, 0, 1) == (None, None, None)


def test_ecart_au_hasard():
    stat, p = ecart_au_hasard([31, 28, 31], [31, 28, 31])
    assert stat == 0 and p == 1
    _, p = ecart_au_hasard([300, 10, 10], [1, 1, 1])
    assert p < 1e-6
    assert not math.isnan(p)
