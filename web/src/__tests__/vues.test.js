import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createMemoryHistory } from 'vue-router';

// Chart.js a besoin d'un vrai canvas : on le remplace dans les tests
vi.mock('chart.js', () => {
  class Chart {
    constructor(_toile, config) {
      this.data = config.data;
      this.options = config.options;
      Chart.dernier = this;
    }
    update() {}
    destroy() {}
    toBase64Image() { return 'data:image/png;base64,'; }
    static register() {}
  }
  return { Chart, ArcElement: {}, BarController: {}, BarElement: {}, CategoryScale: {}, DoughnutController: {}, Filler: {},
    Legend: {}, LinearScale: {}, LineController: {}, LineElement: {}, PointElement: {}, Tooltip: {} };
});

import App from '../App.vue';
import { creerRouteur } from '../routeur.js';

const ACCIDENT = {
  id: '11111111-1111-1111-1111-111111111111', date: '2025-03-14', occurredAt: '2025-03-14T17:35:00Z', mode: 'road',
  severity: 'serious', severityLabel: 'Blessé hospitalisé', fatalities: 0, seriousInjuries: 1, minorInjuries: 2,
  country: 'FR', department: 'Haute-Garonne', municipality: 'Toulouse', source: 'sim_demo',
  validationStatus: 'unverified', simulated: true,
};

const DETAIL = {
  ...ACCIDENT, category: 'collision_2_vehicules', summary: 'SIMULÉ', confidence: 'medium', validatedAt: null,
  location: { lat: 43.6, lon: 1.44, precision: 'exact', country: 'FR', municipality: 'Toulouse', inseeCode: '31555' },
  source: { code: 'sim_demo', name: 'Jeu simulé', license: 'CC0', sourceRef: 'SIM-ROAD-0001', importJobId: null },
  factors: [
    { category: 'environmental', description: 'Chaussée mouillée', assertion: 'established', statedBy: 'source_data' },
    { category: 'human', description: 'Refus de priorité possible', assertion: 'hypothesis', statedBy: 'internal_analysis' },
  ],
};

const APERCU = {
  totals: { accidents: 54822, fatalAccidents: 3203, fatalities: 3398, seriousInjuries: 16582 },
  modes: [{ key: 'road', accidents: 54822, fatalities: 3398 }],
  severities: [{ key: 'fatal', accidents: 3203, fatalities: 3398 }, { key: 'minor', accidents: 35037, fatalities: 0 }],
  months: [{ key: '2023-01', accidents: 4000, fatalities: 250 }],
  sources: ['ONISR BAAC'],
};

function reponse(corps, status = 200) {
  return Promise.resolve({ ok: status < 400, status, json: () => Promise.resolve(corps) });
}

let appels;
window.scrollTo = () => {};

function simulerApi(statutAccidents = 200) {
  appels = [];
  globalThis.fetch = vi.fn((url, options = {}) => {
    appels.push({ url, options });
    if (url.startsWith('/api/v1/auth/login')) return reponse({ token: 'jeton-test', username: 'analyste.demo', roles: ['analyst'] });
    if (url.startsWith('/api/v1/sources')) return reponse([{ code: 'onisr_baac', name: 'ONISR BAAC' }]);
    if (url.startsWith('/api/v1/accidents/stats/overview')) return reponse(APERCU);
    if (url.startsWith('/api/v1/accidents/stats')) return reponse({ years: [{ year: 2025, accidents: 1, fatalAccidents: 0, fatalities: 0 }], sources: ['Jeu simulé'] });
    if (url.startsWith(`/api/v1/accidents/${ACCIDENT.id}`)) return reponse(DETAIL);
    if (url.startsWith('/api/v1/accidents')) return reponse({ items: [ACCIDENT], total: 1, page: 0, size: 50 }, statutAccidents);
    return reponse({ status: 'ok' });
  });
}

async function monter(chemin) {
  const routeur = creerRouteur(createMemoryHistory());
  routeur.push(chemin);
  await routeur.isReady();
  const wrapper = mount(App, { global: { plugins: [routeur] } });
  await flushPromises();
  return { wrapper, routeur };
}

beforeEach(() => {
  localStorage.clear();
  simulerApi();
});

describe('application', () => {
  it('renvoie vers la connexion sans jeton', async () => {
    const { routeur } = await monter('/');
    expect(routeur.currentRoute.value.name).toBe('connexion');
  });

  it('se connecte puis affiche le tableau de bord', async () => {
    const { wrapper, routeur } = await monter('/connexion');
    await wrapper.find('input[name=username]').setValue('analyste.demo');
    await wrapper.find('input[name=password]').setValue('demo');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(localStorage.getItem('safetransport.jeton')).toBe('jeton-test');
    expect(routeur.currentRoute.value.name).toBe('tableau');
    expect(wrapper.text()).toContain('Tableau de bord');
  });

  it('le tableau de bord montre les chiffres clés et sa source', async () => {
    localStorage.setItem('safetransport.jeton', 'jeton-test');
    const { wrapper } = await monter('/?annee=2023&mode=road');
    const apercu = appels.find((a) => a.url.startsWith('/api/v1/accidents/stats/overview'));
    expect(apercu.url).toContain('from=2023-01-01');
    expect(apercu.url).toContain('to=2023-12-31');
    expect(apercu.url).toContain('mode=road');
    expect(wrapper.text()).toContain('Personnes tuées');
    expect(wrapper.text()).toContain('5,8 % des accidents');
    expect(wrapper.text()).toContain('Sources : ONISR BAAC');
    expect(wrapper.text()).toContain('nombres bruts');
  });

  it('la recherche affiche le nombre de résultats', async () => {
    localStorage.setItem('safetransport.jeton', 'jeton-test');
    const { wrapper } = await monter('/recherche');
    expect(wrapper.text()).toContain('1 accident(s)');
  });

  it('envoie le jeton et étiquette un accident simulé et non vérifié', async () => {
    localStorage.setItem('safetransport.jeton', 'jeton-test');
    const { wrapper } = await monter('/recherche?includeSimulated=true&includeUnverified=true');
    const liste = appels.find((a) => a.url.startsWith('/api/v1/accidents?'));
    expect(liste.options.headers.Authorization).toBe('Bearer jeton-test');
    expect(liste.url).toContain('includeSimulated=true');
    expect(wrapper.find('.etiquette.simule').exists()).toBe(true);
    expect(wrapper.find('.etiquette.non-verifie').text()).toBe('Non vérifié');
    expect(wrapper.text()).toContain('Source : Jeu simulé');
  });

  it('le graphique suit les mêmes filtres que la liste', async () => {
    localStorage.setItem('safetransport.jeton', 'jeton-test');
    await monter('/recherche?mode=air&severity=fatal');
    const stats = appels.find((a) => a.url.startsWith('/api/v1/accidents/stats'));
    expect(stats.url).toContain('mode=air');
    expect(stats.url).toContain('severity=fatal');
  });

  it('appliquer les filtres change l\'adresse', async () => {
    localStorage.setItem('safetransport.jeton', 'jeton-test');
    const { wrapper, routeur } = await monter('/recherche');
    await wrapper.find('input[name=mode][value=road]').setValue(true);
    await wrapper.find('form.filtres').trigger('submit');
    await flushPromises();
    expect(routeur.currentRoute.value.query.mode).toBe('road');
  });

  it('un jeton expiré ramène à la connexion', async () => {
    localStorage.setItem('safetransport.jeton', 'perime');
    simulerApi(401);
    const { routeur } = await monter('/recherche');
    expect(routeur.currentRoute.value.name).toBe('connexion');
    expect(localStorage.getItem('safetransport.jeton')).toBeNull();
  });

  it('la fiche montre la source et le statut des facteurs', async () => {
    localStorage.setItem('safetransport.jeton', 'jeton-test');
    const { wrapper } = await monter(`/accidents/${ACCIDENT.id}`);
    expect(wrapper.text()).toContain('libellé de la source : Blessé hospitalisé');
    expect(wrapper.text()).toContain('SIM-ROAD-0001');
    expect(wrapper.text()).toContain('Donnée simulée');
    const etiquettes = wrapper.findAll('.facteurs .etiquette').map((e) => e.text());
    expect(etiquettes).toEqual(['Fait établi', 'Hypothèse']);
  });
});
