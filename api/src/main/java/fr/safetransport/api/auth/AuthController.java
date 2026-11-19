package fr.safetransport.api.auth;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import fr.safetransport.api.common.Audit;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    public record Connexion(@NotBlank String username, @NotBlank String password) {
    }

    public record Jeton(String token, String type, long expiresIn, String username, List<String> roles) {
    }

    private final CompteRepository comptes;
    private final PasswordEncoder motsDePasse;
    private final JwtEncoder encodeur;
    private final Audit audit;
    private final long dureeHeures;

    public AuthController(CompteRepository comptes, PasswordEncoder motsDePasse, JwtEncoder encodeur, Audit audit,
                          @Value("${safetransport.jwt.duree-heures:8}") long dureeHeures) {
        this.comptes = comptes;
        this.motsDePasse = motsDePasse;
        this.encodeur = encodeur;
        this.audit = audit;
        this.dureeHeures = dureeHeures;
    }

    @PostMapping("/login")
    @Transactional
    public Jeton login(@Valid @RequestBody Connexion demande) {
        Compte compte = comptes.parNom(demande.username())
            .filter(c -> c.passwordHash() != null && motsDePasse.matches(demande.password(), c.passwordHash()))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "identifiants invalides"));

        Instant maintenant = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer("safetransport-api")
            .subject(compte.username())
            .issuedAt(maintenant)
            .expiresAt(maintenant.plus(dureeHeures, ChronoUnit.HOURS))
            .claim("uid", compte.id())
            .claim("roles", compte.roles())
            .build();
        JwsHeader entete = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = encodeur.encode(JwtEncoderParameters.from(entete, claims)).getTokenValue();

        audit.connexion(compte.id());
        return new Jeton(token, "Bearer", dureeHeures * 3600, compte.username(), compte.roles());
    }
}
