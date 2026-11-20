package fr.safetransport.api.accident;

import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import fr.safetransport.api.common.Audit;
import fr.safetransport.api.common.Csv;
import fr.safetransport.api.common.Filtre;
import fr.safetransport.api.common.Page;
import fr.safetransport.api.security.SecurityConfig;
import fr.safetransport.api.security.Utilisateur;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.constraints.NotBlank;

@RestController
@RequestMapping("/api/v1/accidents")
public class AccidentController {

    static final Set<String> GRAVITES = Set.of("none", "minor", "serious", "fatal", "unknown");
    static final Set<String> STATUTS = Set.of("unverified", "under_review", "validated", "rejected", "retracted");

    public record Decision(@NotBlank String status) {
    }

    private final AccidentRepository accidents;
    private final Audit audit;

    public AccidentController(AccidentRepository accidents, Audit audit) {
        this.accidents = accidents;
        this.audit = audit;
    }

    @GetMapping
    @PreAuthorize(SecurityConfig.LECTURE)
    public Page<AccidentResume> list(
            @RequestParam(required = false) String mode,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) List<String> severity,
            @RequestParam(required = false) String country,
            @RequestParam(required = false) String source,
            @RequestParam(defaultValue = "false") boolean includeUnverified,
            @RequestParam(defaultValue = "false") boolean includeSimulated,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        verifierGravites(severity);
        if (page < 0 || size < 1 || size > 200) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "page >= 0 et size entre 1 et 200");
        }
        Filtre filtre = new Filtre(mode, from, to, country, source, includeUnverified, includeSimulated);
        return accidents.chercher(filtre, severity, page, size);
    }

    // Mêmes filtres que la liste, sans pagination
    @GetMapping(value = "/export.csv", produces = "text/csv")
    @PreAuthorize(SecurityConfig.LECTURE)
    public void export(
            @RequestParam(required = false) String mode,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) List<String> severity,
            @RequestParam(required = false) String country,
            @RequestParam(required = false) String source,
            @RequestParam(defaultValue = "false") boolean includeUnverified,
            @RequestParam(defaultValue = "false") boolean includeSimulated,
            HttpServletResponse reponse) throws IOException {
        verifierGravites(severity);
        Filtre filtre = new Filtre(mode, from, to, country, source, includeUnverified, includeSimulated);
        reponse.setContentType("text/csv;charset=UTF-8");
        reponse.setHeader("Content-Disposition", "attachment; filename=\"accidents.csv\"");
        PrintWriter sortie = reponse.getWriter();
        sortie.println(Csv.ligne(Csv.ENTETE));
        accidents.parcourir(filtre, severity, rs -> sortie.println(Csv.ligne(Csv.valeurs(rs))));
        sortie.flush();
    }

    @GetMapping("/stats/annual")
    @PreAuthorize(SecurityConfig.LECTURE)
    public Statistiques parAnnee(
            @RequestParam(required = false) String mode,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) List<String> severity,
            @RequestParam(required = false) String country,
            @RequestParam(required = false) String source,
            @RequestParam(defaultValue = "false") boolean includeUnverified,
            @RequestParam(defaultValue = "false") boolean includeSimulated) {
        verifierGravites(severity);
        Filtre filtre = new Filtre(mode, from, to, country, source, includeUnverified, includeSimulated);
        return accidents.parAnnee(filtre, severity);
    }

    @GetMapping("/stats/overview")
    @PreAuthorize(SecurityConfig.LECTURE)
    public Apercu apercu(
            @RequestParam(required = false) String mode,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) List<String> severity,
            @RequestParam(required = false) String country,
            @RequestParam(required = false) String source,
            @RequestParam(defaultValue = "false") boolean includeUnverified,
            @RequestParam(defaultValue = "false") boolean includeSimulated) {
        verifierGravites(severity);
        Filtre filtre = new Filtre(mode, from, to, country, source, includeUnverified, includeSimulated);
        return accidents.apercu(filtre, severity);
    }

    @GetMapping("/{id}")
    @PreAuthorize(SecurityConfig.LECTURE)
    public AccidentDetail detail(@PathVariable UUID id) {
        return accidents.detail(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "accident inconnu"));
    }

    @PatchMapping("/{id}/validation")
    @PreAuthorize(SecurityConfig.VALIDATION)
    @Transactional
    public AccidentDetail valider(@PathVariable UUID id, @RequestBody Decision decision, Authentication auth) {
        if (!STATUTS.contains(decision.status())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "statut inconnu : " + decision.status());
        }
        audit.auteur(Utilisateur.id(auth));
        if (accidents.changerStatut(id, decision.status(), Utilisateur.id(auth)) == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "accident inconnu");
        }
        return accidents.detail(id).orElseThrow();
    }

    static void verifierGravites(List<String> gravites) {
        if (gravites != null && !GRAVITES.containsAll(gravites)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "gravité inconnue, valeurs possibles : " + GRAVITES);
        }
    }
}
