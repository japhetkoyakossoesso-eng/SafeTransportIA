package fr.safetransport.api.source;

import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/sources")
public class SourceController {

    private static final String SQL = """
        SELECT s.code, s.name, s.kind, o.acronym AS provider, m.code AS mode, s.country_code,
               s.url, s.license, s.data_format, s.data_dictionary_url, s.known_biases,
               s.default_confidence, s.validation_status, s.is_simulated
        FROM core.data_sources s
        LEFT JOIN core.organizations o ON o.id = s.provider_org_id
        LEFT JOIN core.transport_modes m ON m.id = s.transport_mode_id
        WHERE s.is_active AND (? OR NOT s.is_simulated)
        ORDER BY s.code
        """;

    private final JdbcTemplate jdbc;

    public SourceController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // Les sources simulées sont cachées sauf si on les demande
    @GetMapping
    public List<Map<String, Object>> list(@RequestParam(defaultValue = "false") boolean includeSimulated) {
        return jdbc.queryForList(SQL, includeSimulated);
    }
}
