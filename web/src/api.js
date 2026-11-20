const CLE = 'safetransport.jeton';

export function lireJeton() {
  try {
    return localStorage.getItem(CLE);
  } catch {
    return null;
  }
}

export function enregistrerJeton(jeton) {
  try {
    if (jeton) localStorage.setItem(CLE, jeton);
    else localStorage.removeItem(CLE);
  } catch {
    // stockage indisponible (navigation privée) : on reste connecté pour cette page seulement
  }
}

export class NonConnecte extends Error {}

// Les filtres vides ne sont pas envoyés ; une liste donne un paramètre répété
export function versParametres(filtres) {
  const p = new URLSearchParams();
  for (const [cle, valeur] of Object.entries(filtres)) {
    if (valeur === '' || valeur === null || valeur === undefined || valeur === false) continue;
    if (Array.isArray(valeur)) valeur.forEach((v) => p.append(cle, v));
    else p.append(cle, String(valeur));
  }
  return p;
}

async function appeler(chemin, options = {}) {
  const jeton = lireJeton();
  const entetes = { ...(options.headers || {}) };
  if (jeton) entetes.Authorization = `Bearer ${jeton}`;
  const reponse = await fetch(chemin, { ...options, headers: entetes });
  if (reponse.status === 401) {
    enregistrerJeton(null);
    throw new NonConnecte('Session expirée, reconnectez-vous');
  }
  if (!reponse.ok) {
    let message = `Erreur ${reponse.status}`;
    try {
      message = (await reponse.json()).message || message;
    } catch {
      // pas de corps JSON
    }
    throw new Error(message);
  }
  return reponse;
}

export async function connexion(username, password) {
  const reponse = await fetch('/api/v1/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
  if (!reponse.ok) throw new Error('Identifiant ou mot de passe incorrect');
  const corps = await reponse.json();
  enregistrerJeton(corps.token);
  try {
    localStorage.setItem('safetransport.utilisateur', JSON.stringify({ username: corps.username, roles: corps.roles }));
  } catch {
    // idem
  }
  return corps;
}

export function lireUtilisateur() {
  try {
    return JSON.parse(localStorage.getItem('safetransport.utilisateur') || '{}');
  } catch {
    return {};
  }
}

export function deconnexion() {
  enregistrerJeton(null);
}

export async function lire(chemin, filtres = {}) {
  const p = versParametres(filtres).toString();
  return (await appeler(p ? `${chemin}?${p}` : chemin)).json();
}

export async function telechargerCsv(filtres) {
  const reponse = await appeler(`/api/v1/accidents/export.csv?${versParametres(filtres)}`);
  const lien = document.createElement('a');
  lien.href = URL.createObjectURL(await reponse.blob());
  lien.download = 'accidents.csv';
  lien.click();
  URL.revokeObjectURL(lien.href);
}
