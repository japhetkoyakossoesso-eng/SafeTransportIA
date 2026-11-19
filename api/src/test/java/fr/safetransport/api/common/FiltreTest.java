package fr.safetransport.api.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;

class FiltreTest {

    @Test
    void parDefautValidesEtReels() {
        MapSqlParameterSource p = new MapSqlParameterSource();
        assertThat(new Filtre(null, null, null, null, null, false, false).conditions(p))
            .containsExactly("e.validation_status = 'validated'", "NOT e.is_simulated");
    }

    @Test
    void filtresCombines() {
        MapSqlParameterSource p = new MapSqlParameterSource();
        Filtre f = new Filtre("road", LocalDate.of(2023, 1, 1), LocalDate.of(2023, 12, 31), "fr", "onisr_baac",
            true, true);
        assertThat(f.conditions(p)).hasSize(6).doesNotContain("NOT e.is_simulated");
        assertThat(p.getValue("country")).isEqualTo("FR");
    }

    @Test
    void csvEchappeLesPointsVirgules() {
        assertThat(Csv.ligne(java.util.Arrays.asList("a;b", null, "c\"d")))
            .isEqualTo("\"a;b\";;\"c\"\"d\"");
    }
}
