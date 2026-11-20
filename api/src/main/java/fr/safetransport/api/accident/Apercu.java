package fr.safetransport.api.accident;

import java.util.List;

// Chiffres du tableau de bord : totaux puis répartitions par mode, gravité et mois
public record Apercu(Totaux totals, List<Groupe> modes, List<Groupe> severities, List<Groupe> months,
        List<String> sources) {

    public record Totaux(long accidents, long fatalAccidents, long fatalities, long seriousInjuries) {
    }

    public record Groupe(String key, long accidents, long fatalities) {
    }
}
