package fr.safetransport.api.incident;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import fr.safetransport.api.common.Filtre;
import fr.safetransport.api.common.Page;

@Repository
public class IncidentRepository {

    private static final String SELECT = """
        SELECT e.public_id, e.occurred_date, e.occurred_at, m.code AS mode, e.incident_class, e.category,
               e.minor_injuries, e.summary, l.country_code, l.municipality, l.site_name, s.code AS source,
               e.validation_status, e.is_simulated, a.public_id AS accident_id
        FROM core.incidents e
        JOIN core.transport_modes m ON m.id = e.transport_mode_id
        JOIN core.data_sources s ON s.id = e.data_source_id
        LEFT JOIN core.locations l ON l.id = e.location_id
        LEFT JOIN core.accidents a ON a.id = e.escalated_to_accident_id
        """;

    private final NamedParameterJdbcTemplate jdbc;

    public IncidentRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Page<IncidentResume> chercher(Filtre filtre, String classe, int page, int size) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        List<String> c = filtre.conditions(p);
        if (classe != null && !classe.isBlank()) {
            c.add("e.incident_class::text = :classe");
            p.addValue("classe", classe);
        }
        String where = " WHERE " + String.join(" AND ", c);
        String compte = "SELECT count(*) FROM core.incidents e "
            + "JOIN core.transport_modes m ON m.id = e.transport_mode_id "
            + "JOIN core.data_sources s ON s.id = e.data_source_id "
            + "LEFT JOIN core.locations l ON l.id = e.location_id" + where;
        Long total = jdbc.queryForObject(compte, p, Long.class);
        p.addValue("limit", size).addValue("offset", (long) page * size);
        List<IncidentResume> items = jdbc.query(
            SELECT + where + " ORDER BY e.occurred_date DESC, e.id DESC LIMIT :limit OFFSET :offset",
            p, (rs, i) -> resume(rs));
        return new Page<>(items, total == null ? 0 : total, page, size);
    }

    public Optional<IncidentResume> detail(UUID id) {
        return jdbc.query(SELECT + " WHERE e.public_id = :id", new MapSqlParameterSource("id", id),
            (rs, i) -> resume(rs)).stream().findFirst();
    }

    private static IncidentResume resume(ResultSet rs) throws SQLException {
        int blesses = rs.getInt("minor_injuries");
        Integer minorInjuries = rs.wasNull() ? null : blesses;
        return new IncidentResume(
            rs.getObject("public_id", UUID.class),
            rs.getObject("occurred_date", LocalDate.class),
            rs.getObject("occurred_at", OffsetDateTime.class),
            rs.getString("mode"),
            rs.getString("incident_class"),
            rs.getString("category"),
            minorInjuries,
            rs.getString("summary"),
            rs.getString("country_code"),
            rs.getString("municipality"),
            rs.getString("site_name"),
            rs.getString("source"),
            rs.getString("validation_status"),
            rs.getBoolean("is_simulated"),
            rs.getObject("accident_id", UUID.class));
    }
}
