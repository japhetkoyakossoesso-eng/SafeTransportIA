package fr.safetransport.api.accident;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.RowCallbackHandler;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import fr.safetransport.api.common.Filtre;
import fr.safetransport.api.common.Page;

@Repository
public class AccidentRepository {

    static final String FROM = """
        FROM core.accidents e
        JOIN core.transport_modes m ON m.id = e.transport_mode_id
        JOIN core.data_sources s ON s.id = e.data_source_id
        LEFT JOIN core.locations l ON l.id = e.location_id
        """;

    static final String COLONNES = """
        SELECT e.public_id, e.occurred_date, e.occurred_at, m.code AS mode, e.severity, e.severity_source_label,
               e.fatalities, e.serious_injuries, e.minor_injuries, l.country_code, l.admin2, l.municipality,
               l.insee_code, s.code AS source, e.validation_status, e.is_simulated,
               ST_Y(l.geom::geometry) AS lat, ST_X(l.geom::geometry) AS lon, l.precision
        """;

    private final NamedParameterJdbcTemplate jdbc;

    public AccidentRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    static String where(Filtre filtre, List<String> gravites, MapSqlParameterSource p) {
        List<String> c = filtre.conditions(p);
        if (gravites != null && !gravites.isEmpty()) {
            c.add("e.severity::text IN (:severity)");
            p.addValue("severity", gravites);
        }
        return " WHERE " + String.join(" AND ", c);
    }

    public Page<AccidentResume> chercher(Filtre filtre, List<String> gravites, int page, int size) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        String where = where(filtre, gravites, p);
        Long total = jdbc.queryForObject("SELECT count(*) " + FROM + where, p, Long.class);
        p.addValue("limit", size).addValue("offset", (long) page * size);
        List<AccidentResume> items = jdbc.query(
            COLONNES + FROM + where + " ORDER BY e.occurred_date DESC, e.id DESC LIMIT :limit OFFSET :offset",
            p, (rs, i) -> resume(rs));
        return new Page<>(items, total == null ? 0 : total, page, size);
    }

    // Pour l'export CSV : on parcourt les lignes sans tout garder en mémoire
    public void parcourir(Filtre filtre, List<String> gravites, RowCallbackHandler ligne) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        String sql = COLONNES + FROM + where(filtre, gravites, p) + " ORDER BY e.occurred_date DESC, e.id DESC";
        jdbc.query(sql, p, ligne);
    }

    // Évolution annuelle avec les mêmes filtres que la liste
    public Statistiques parAnnee(Filtre filtre, List<String> gravites) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        String where = where(filtre, gravites, p);
        List<Statistiques.Annee> annees = jdbc.query(
            "SELECT extract(year FROM e.occurred_date)::int AS annee, count(*) AS accidents, "
                + "count(*) FILTER (WHERE e.severity = 'fatal') AS mortels, "
                + "coalesce(sum(e.fatalities), 0) AS tues " + FROM + where + " GROUP BY 1 ORDER BY 1",
            p, (rs, i) -> new Statistiques.Annee(rs.getInt("annee"), rs.getLong("accidents"),
                rs.getLong("mortels"), rs.getLong("tues")));
        List<String> sources = jdbc.queryForList("SELECT DISTINCT s.name " + FROM + where + " ORDER BY 1",
            p, String.class);
        return new Statistiques(annees, sources);
    }

    public Apercu apercu(Filtre filtre, List<String> gravites) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        String where = where(filtre, gravites, p);
        Apercu.Totaux totaux = jdbc.queryForObject(
            "SELECT count(*) AS accidents, count(*) FILTER (WHERE e.severity = 'fatal') AS mortels, "
                + "coalesce(sum(e.fatalities), 0) AS tues, coalesce(sum(e.serious_injuries), 0) AS graves "
                + FROM + where,
            p, (rs, i) -> new Apercu.Totaux(rs.getLong("accidents"), rs.getLong("mortels"), rs.getLong("tues"),
                rs.getLong("graves")));
        return new Apercu(totaux,
            groupes("m.code", where, p),
            groupes("e.severity::text", where, p),
            groupes("to_char(e.occurred_date, 'YYYY-MM')", where, p),
            jdbc.queryForList("SELECT DISTINCT s.name " + FROM + where + " ORDER BY 1", p, String.class));
    }

    private List<Apercu.Groupe> groupes(String cle, String where, MapSqlParameterSource p) {
        return jdbc.query("SELECT " + cle + " AS cle, count(*) AS accidents, coalesce(sum(e.fatalities), 0) AS tues "
                + FROM + where + " GROUP BY 1 ORDER BY 1",
            p, (rs, i) -> new Apercu.Groupe(rs.getString("cle"), rs.getLong("accidents"), rs.getLong("tues")));
    }

    public Optional<AccidentDetail> detail(UUID id) {
        MapSqlParameterSource p = new MapSqlParameterSource("id", id);
        List<AccidentDetail> trouves = jdbc.query("""
            SELECT e.id AS cle, e.public_id, e.occurred_date, e.occurred_at, m.code AS mode, e.category,
                   e.severity, e.severity_source_label, e.fatalities, e.serious_injuries, e.minor_injuries,
                   e.summary, e.confidence, e.validation_status, e.validated_at, e.is_simulated, e.source_ref,
                   ST_Y(l.geom::geometry) AS lat, ST_X(l.geom::geometry) AS lon, l.precision, l.country_code,
                   l.admin1, l.admin2, l.municipality, l.insee_code, l.site_name,
                   s.code AS source, s.name AS source_name, s.license, r.import_job_id
            """ + FROM + """
            LEFT JOIN core.source_records r ON r.id = e.source_record_id
            WHERE e.public_id = :id
            """, p, (rs, i) -> new AccidentDetail(
                rs.getObject("public_id", UUID.class),
                rs.getObject("occurred_date", LocalDate.class),
                rs.getObject("occurred_at", OffsetDateTime.class),
                rs.getString("mode"),
                rs.getString("category"),
                rs.getString("severity"),
                rs.getString("severity_source_label"),
                entier(rs, "fatalities"),
                entier(rs, "serious_injuries"),
                entier(rs, "minor_injuries"),
                rs.getString("summary"),
                new AccidentDetail.Lieu(reel(rs, "lat"), reel(rs, "lon"), rs.getString("precision"),
                    rs.getString("country_code"), rs.getString("admin1"), rs.getString("admin2"),
                    rs.getString("municipality"), rs.getString("insee_code"), rs.getString("site_name")),
                new AccidentDetail.Source(rs.getString("source"), rs.getString("source_name"),
                    rs.getString("license"), rs.getString("source_ref"), (Long) rs.getObject("import_job_id")),
                rs.getString("confidence"),
                rs.getString("validation_status"),
                rs.getObject("validated_at", OffsetDateTime.class),
                rs.getBoolean("is_simulated"),
                facteurs(rs.getLong("cle"))));
        return trouves.stream().findFirst();
    }

    private List<AccidentDetail.Facteur> facteurs(long accidentId) {
        return jdbc.query("""
            SELECT category, factor_code, description, assertion_level, confidence, stated_by
            FROM core.accident_factors WHERE accident_id = :id ORDER BY assertion_level, id
            """, new MapSqlParameterSource("id", accidentId), (rs, i) -> new AccidentDetail.Facteur(
                rs.getString("category"), rs.getString("factor_code"), rs.getString("description"),
                rs.getString("assertion_level"), rs.getString("confidence"), rs.getString("stated_by")));
    }

    public int changerStatut(UUID id, String statut, Long userId) {
        return jdbc.update("""
            UPDATE core.accidents
            SET validation_status = CAST(:statut AS core.validation_status),
                validated_by = CASE WHEN :statut = 'validated' THEN CAST(:user AS bigint) ELSE NULL END,
                validated_at = CASE WHEN :statut = 'validated' THEN now() ELSE NULL END
            WHERE public_id = :id
            """, new MapSqlParameterSource("id", id).addValue("statut", statut).addValue("user", userId));
    }

    static AccidentResume resume(ResultSet rs) throws SQLException {
        return new AccidentResume(
            rs.getObject("public_id", UUID.class),
            rs.getObject("occurred_date", LocalDate.class),
            rs.getObject("occurred_at", OffsetDateTime.class),
            rs.getString("mode"),
            rs.getString("severity"),
            rs.getString("severity_source_label"),
            entier(rs, "fatalities"),
            entier(rs, "serious_injuries"),
            entier(rs, "minor_injuries"),
            rs.getString("country_code"),
            rs.getString("admin2"),
            rs.getString("municipality"),
            rs.getString("source"),
            rs.getString("validation_status"),
            rs.getBoolean("is_simulated"));
    }

    static Integer entier(ResultSet rs, String colonne) throws SQLException {
        int v = rs.getInt(colonne);
        return rs.wasNull() ? null : v;
    }

    static Double reel(ResultSet rs, String colonne) throws SQLException {
        double v = rs.getDouble(colonne);
        return rs.wasNull() ? null : v;
    }
}
