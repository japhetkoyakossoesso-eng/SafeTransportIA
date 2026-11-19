package fr.safetransport.api.incident;

import java.time.LocalDate;
import java.util.UUID;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import fr.safetransport.api.common.Filtre;
import fr.safetransport.api.common.Page;
import fr.safetransport.api.security.SecurityConfig;

@RestController
@RequestMapping("/api/v1/incidents")
public class IncidentController {

    private final IncidentRepository incidents;

    public IncidentController(IncidentRepository incidents) {
        this.incidents = incidents;
    }

    @GetMapping
    @PreAuthorize(SecurityConfig.LECTURE)
    public Page<IncidentResume> list(
            @RequestParam(required = false) String mode,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String incidentClass,
            @RequestParam(required = false) String country,
            @RequestParam(required = false) String source,
            @RequestParam(defaultValue = "false") boolean includeUnverified,
            @RequestParam(defaultValue = "false") boolean includeSimulated,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        if (page < 0 || size < 1 || size > 200) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "page >= 0 et size entre 1 et 200");
        }
        Filtre filtre = new Filtre(mode, from, to, country, source, includeUnverified, includeSimulated);
        return incidents.chercher(filtre, incidentClass, page, size);
    }

    @GetMapping("/{id}")
    @PreAuthorize(SecurityConfig.LECTURE)
    public IncidentResume detail(@PathVariable UUID id) {
        return incidents.detail(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "incident inconnu"));
    }
}
