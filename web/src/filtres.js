export const VIDE = {
  mode: '',
  from: '',
  to: '',
  severity: [],
  country: '',
  source: '',
  includeUnverified: false,
  includeSimulated: false,
};

// Les filtres vivent dans l'adresse : la liste, le graphique et l'export lisent les mêmes
export function depuisQuery(query) {
  const liste = (v) => (v === undefined ? [] : [].concat(v));
  return {
    mode: query.mode || '',
    from: query.from || '',
    to: query.to || '',
    severity: liste(query.severity),
    country: query.country || '',
    source: query.source || '',
    includeUnverified: query.includeUnverified === 'true',
    includeSimulated: query.includeSimulated === 'true',
  };
}

export function versQuery(filtres, page = 0) {
  const q = {};
  for (const [cle, valeur] of Object.entries(filtres)) {
    if (Array.isArray(valeur) ? valeur.length : valeur) q[cle] = valeur === true ? 'true' : valeur;
  }
  if (page > 0) q.page = String(page);
  return q;
}
