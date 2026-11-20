export const MODES = { road: 'Routier', air: 'Aérien', rail: 'Ferroviaire', maritime: 'Maritime' };

export const GRAVITES = {
  fatal: 'Mortel',
  serious: 'Grave',
  minor: 'Léger',
  none: 'Sans blessé',
  unknown: 'Inconnue',
};

export const STATUTS = {
  validated: 'Validé',
  unverified: 'Non vérifié',
  under_review: 'En revue',
  rejected: 'Rejeté',
  retracted: 'Retiré',
};

export const ASSERTIONS = { established: 'Fait établi', probable: 'Probable', hypothesis: 'Hypothèse' };

export const PRECISIONS = {
  exact: 'point exact',
  approximate: 'point approximatif',
  municipality: 'localisé à la commune',
  region: 'localisé à la région',
  country: 'localisé au pays',
  unknown: 'lieu inconnu',
};

export function date(iso) {
  if (!iso) return '';
  const [a, m, j] = iso.slice(0, 10).split('-');
  return `${j}/${m}/${a}`;
}

export function heure(iso) {
  if (!iso) return 'heure inconnue';
  return new Date(iso).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit', timeZone: 'UTC' }) + ' UTC';
}
