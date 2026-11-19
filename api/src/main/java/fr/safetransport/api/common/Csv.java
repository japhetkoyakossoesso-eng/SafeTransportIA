package fr.safetransport.api.common;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.List;

public final class Csv {

    // Aucune colonne du schéma sensitive
    public static final List<String> ENTETE = List.of("id", "date", "heure_utc", "mode", "gravite", "libelle_source",
        "tues", "blesses_graves", "blesses_legers", "pays", "departement", "commune", "code_insee", "lat", "lon",
        "precision_lieu", "source", "statut_validation", "simule");

    private Csv() {
    }

    public static List<String> valeurs(ResultSet rs) throws SQLException {
        OffsetDateTime heure = rs.getObject("occurred_at", OffsetDateTime.class);
        return Arrays.asList(
            rs.getString("public_id"), rs.getString("occurred_date"),
            heure == null ? null : heure.withOffsetSameInstant(ZoneOffset.UTC).toString(),
            rs.getString("mode"), rs.getString("severity"), rs.getString("severity_source_label"),
            rs.getString("fatalities"), rs.getString("serious_injuries"), rs.getString("minor_injuries"),
            rs.getString("country_code"), rs.getString("admin2"), rs.getString("municipality"),
            rs.getString("insee_code"), rs.getString("lat"), rs.getString("lon"), rs.getString("precision"),
            rs.getString("source"), rs.getString("validation_status"), rs.getBoolean("is_simulated") ? "oui" : "non");
    }

    public static String ligne(List<String> valeurs) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < valeurs.size(); i++) {
            if (i > 0) {
                sb.append(';');
            }
            String v = valeurs.get(i);
            if (v != null) {
                boolean guillemets = v.contains(";") || v.contains("\"") || v.contains("\n");
                sb.append(guillemets ? "\"" + v.replace("\"", "\"\"") + "\"" : v);
            }
        }
        return sb.toString();
    }
}
