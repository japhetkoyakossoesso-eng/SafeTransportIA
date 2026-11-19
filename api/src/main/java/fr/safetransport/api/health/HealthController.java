package fr.safetransport.api.health;

import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class HealthController {

    private final JdbcTemplate jdbc;

    public HealthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        try {
            String db = jdbc.queryForObject("SELECT 'postgis ' || postgis_lib_version()", String.class);
            return Map.of("service", "api", "status", "ok", "database", db);
        } catch (Exception e) {
            return Map.of("service", "api", "status", "degraded", "database", "indisponible");
        }
    }

    @GetMapping("/transport-modes")
    public List<Map<String, Object>> transportModes() {
        return jdbc.queryForList("SELECT code, label_fr, label_en FROM core.transport_modes ORDER BY code");
    }
}
