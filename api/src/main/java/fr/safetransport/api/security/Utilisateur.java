package fr.safetransport.api.security;

import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;

public final class Utilisateur {

    private Utilisateur() {
    }

    // Identifiant core.users mis dans le jeton à la connexion
    public static Long id(Authentication auth) {
        if (auth != null && auth.getPrincipal() instanceof Jwt jwt) {
            Object uid = jwt.getClaim("uid");
            if (uid instanceof Number n) {
                return n.longValue();
            }
        }
        return null;
    }
}
