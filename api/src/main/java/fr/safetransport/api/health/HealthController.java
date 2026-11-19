package fr.safetransport.api.health;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Stub de démarrage : vérifie que l'API répond et qu'elle lit la base.
 * Les vrais contrôleurs (accidents, incidents, signalements…) viendront en phase API.
 */
@RestController
@RequestMapping("/api/v1")
public class HealthController {

    private final JdbcTemplate jdbc;

    public HealthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("service", "api");
        body.put("status", "ok");
        try {
            body.put("database", jdbc.queryForObject(
                "SELECT 'postgres ' || current_setting('server_version') || ', postgis ' || postgis_lib_version()",
                String.class));
        } catch (Exception e) {
            body.put("status", "degraded");
            body.put("database", "indisponible : " + e.getClass().getSimpleName());
        }
        return body;
    }

    /** Lecture du référentiel des modes de transport (données de seed). */
    @GetMapping("/transport-modes")
    public List<Map<String, Object>> transportModes() {
        return jdbc.queryForList("SELECT code, label_fr, label_en FROM core.transport_modes ORDER BY code");
    }
}
