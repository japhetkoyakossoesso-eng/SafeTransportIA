import { describe, expect, it } from 'vitest';
import { versParametres } from '../api.js';
import { depuisQuery, versQuery } from '../filtres.js';

describe('filtres', () => {
  it('passe de l\'adresse aux filtres et retour', () => {
    const f = depuisQuery({ mode: 'road', severity: 'fatal', includeSimulated: 'true' });
    expect(f.severity).toEqual(['fatal']);
    expect(f.includeSimulated).toBe(true);
    expect(f.includeUnverified).toBe(false);
    expect(versQuery(f)).toEqual({ mode: 'road', severity: ['fatal'], includeSimulated: 'true' });
  });

  it('garde la page seulement après la première', () => {
    expect(versQuery(depuisQuery({}), 0)).toEqual({});
    expect(versQuery(depuisQuery({}), 2)).toEqual({ page: '2' });
  });

  it('n\'envoie pas les filtres vides et répète les listes', () => {
    const p = versParametres({ mode: '', severity: ['fatal', 'serious'], includeUnverified: false, page: 0 });
    expect(p.toString()).toBe('severity=fatal&severity=serious&page=0');
  });
});
