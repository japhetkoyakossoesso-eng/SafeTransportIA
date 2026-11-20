package fr.safetransport.api.accident;

import java.util.List;

public record Statistiques(List<Annee> years, List<String> sources) {

    public record Annee(int year, long accidents, long fatalAccidents, long fatalities) {
    }
}
