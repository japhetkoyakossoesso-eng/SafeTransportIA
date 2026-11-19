package fr.safetransport.api.imports;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import fr.safetransport.api.common.Audit;
import fr.safetransport.api.security.SecurityConfig;
import fr.safetransport.api.security.Utilisateur;

// Rapports qualité des imports (US-03) et validation d'un lot par un responsable
@RestController
@RequestMapping("/api/v1/imports")
public class ImportController {

    private static final String SQL = """
        SELECT j.id, s.code AS source, j.status, j.file_name, j.pipeline_name, j.pipeline_version,
               j.started_at, j.finished_at, j.rows_read, j.rows_inserted, j.rows_rejected, j.rows_duplicate,
               j.error_summary::text AS error_summary
        FROM core.import_jobs j
        JOIN core.data_sources s ON s.id = j.data_source_id
        """;

    private final JdbcTemplate jdbc;
    private final Audit audit;

    public ImportController(JdbcTemplate jdbc, Audit audit) {
        this.jdbc = jdbc;
        this.audit = audit;
    }

    @GetMapping
    @PreAuthorize(SecurityConfig.LECTURE)
    public List<Map<String, Object>> list() {
        return jdbc.queryForList(SQL + " ORDER BY j.id DESC LIMIT 100");
    }

    @GetMapping("/{id}")
    @PreAuthorize(SecurityConfig.LECTURE)
    public Map<String, Object> detail(@PathVariable long id) {
        List<Map<String, Object>> lignes = jdbc.queryForList(SQL + " WHERE j.id = ?", id);
        if (lignes.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "import inconnu");
        }
        Map<String, Object> rapport = lignes.get(0);
        rapport.put("rejects", jdbc.queryForList("""
            SELECT external_id, quality_issues::text AS issues FROM core.source_records
            WHERE import_job_id = ? AND quality_status = 'rejected' ORDER BY external_id LIMIT 500
            """, id));
        return rapport;
    }

    // Passe en « validé » les accidents encore non vérifiés de cet import
    @PostMapping("/{id}/validation")
    @PreAuthorize(SecurityConfig.VALIDATION)
    @Transactional
    public Map<String, Object> valider(@PathVariable long id, Authentication auth) {
        Long userId = Utilisateur.id(auth);
        audit.auteur(userId);
        int n = jdbc.update("""
            UPDATE core.accidents a SET validation_status = 'validated', validated_by = ?, validated_at = now()
            FROM core.source_records r
            WHERE r.id = a.source_record_id AND r.import_job_id = ? AND a.validation_status = 'unverified'
            """, userId, id);
        return Map.of("importJobId", id, "validated", n);
    }
}
