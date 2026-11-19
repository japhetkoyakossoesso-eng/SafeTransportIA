package fr.safetransport.api.common;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;

// Filtres communs aux accidents et aux incidents (alias de table « e »)
public record Filtre(String mode, LocalDate from, LocalDate to, String country, String source,
                     boolean includeUnverified, boolean includeSimulated) {

    public List<String> conditions(MapSqlParameterSource p) {
        List<String> c = new ArrayList<>();
        if (mode != null && !mode.isBlank()) {
            c.add("m.code = :mode");
            p.addValue("mode", mode);
        }
        if (from != null) {
            c.add("e.occurred_date >= :from");
            p.addValue("from", from);
        }
        if (to != null) {
            c.add("e.occurred_date <= :to");
            p.addValue("to", to);
        }
        if (country != null && !country.isBlank()) {
            c.add("l.country_code = :country");
            p.addValue("country", country.toUpperCase());
        }
        if (source != null && !source.isBlank()) {
            c.add("s.code = :source");
            p.addValue("source", source);
        }
        // Par défaut : seulement les faits validés et réels
        c.add(includeUnverified ? "e.validation_status NOT IN ('rejected', 'retracted')" : "e.validation_status = 'validated'");
        if (!includeSimulated) {
            c.add("NOT e.is_simulated");
        }
        return c;
    }
}
