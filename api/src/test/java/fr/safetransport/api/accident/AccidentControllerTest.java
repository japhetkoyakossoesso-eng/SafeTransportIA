package fr.safetransport.api.accident;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.JwtRequestPostProcessor;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import fr.safetransport.api.common.Audit;
import fr.safetransport.api.common.Filtre;
import fr.safetransport.api.common.Page;
import fr.safetransport.api.security.SecurityConfig;

@WebMvcTest(AccidentController.class)
@Import(SecurityConfig.class)
class AccidentControllerTest {

    static final UUID ID = UUID.fromString("00000000-0000-0000-0000-000000000001");

    @Autowired
    MockMvc mvc;

    @MockitoBean
    AccidentRepository accidents;

    @MockitoBean
    Audit audit;

    static JwtRequestPostProcessor role(String role) {
        return jwt().jwt(j -> j.claim("uid", 4L)).authorities(new SimpleGrantedAuthority("ROLE_" + role));
    }

    @Test
    void sansJetonRepond401() throws Exception {
        mvc.perform(get("/api/v1/accidents")).andExpect(status().isUnauthorized());
    }

    @Test
    void unDeclarantNeVoitPasLesAccidents() throws Exception {
        mvc.perform(get("/api/v1/accidents").with(role("reporter"))).andExpect(status().isForbidden());
    }

    @Test
    void parDefautSeulementValidesEtReels() throws Exception {
        when(accidents.chercher(any(), any(), anyInt(), anyInt())).thenReturn(new Page<>(List.of(), 0, 0, 50));

        mvc.perform(get("/api/v1/accidents").param("mode", "road").param("severity", "fatal", "serious")
                .with(role("analyst")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.total").value(0));

        ArgumentCaptor<Filtre> filtre = ArgumentCaptor.forClass(Filtre.class);
        verify(accidents).chercher(filtre.capture(), eq(List.of("fatal", "serious")), eq(0), eq(50));
        assertThat(filtre.getValue().includeUnverified()).isFalse();
        assertThat(filtre.getValue().includeSimulated()).isFalse();
        assertThat(filtre.getValue().mode()).isEqualTo("road");
    }

    @Test
    void graviteInconnueRefusee() throws Exception {
        mvc.perform(get("/api/v1/accidents").param("severity", "grave").with(role("analyst")))
            .andExpect(status().isBadRequest());
    }

    @Test
    void tailleDePageLimitee() throws Exception {
        mvc.perform(get("/api/v1/accidents").param("size", "5000").with(role("analyst")))
            .andExpect(status().isBadRequest());
    }

    @Test
    void ficheInconnue404() throws Exception {
        when(accidents.detail(ID)).thenReturn(Optional.empty());
        mvc.perform(get("/api/v1/accidents/" + ID).with(role("researcher"))).andExpect(status().isNotFound());
    }

    @Test
    void unAnalysteNePeutPasValider() throws Exception {
        mvc.perform(patch("/api/v1/accidents/" + ID + "/validation").with(role("analyst"))
                .contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"validated\"}"))
            .andExpect(status().isForbidden());
    }

    @Test
    void unResponsableValideEtLAuteurEstTrace() throws Exception {
        when(accidents.changerStatut(ID, "validated", 4L)).thenReturn(1);
        when(accidents.detail(ID)).thenReturn(Optional.of(new AccidentDetail(ID, null, null, "road", null, "fatal",
            "Tué", 1, 0, 0, null, null, null, "high", "validated", null, false, List.of())));

        mvc.perform(patch("/api/v1/accidents/" + ID + "/validation").with(role("safety_manager"))
                .contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"validated\"}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.validationStatus").value("validated"));

        verify(audit).auteur(4L);
    }

    @Test
    void statutInconnuRefuse() throws Exception {
        mvc.perform(patch("/api/v1/accidents/" + ID + "/validation").with(role("admin"))
                .contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"ok\"}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void statistiquesAnnuellesAvecLesMemesFiltres() throws Exception {
        when(accidents.parAnnee(any(), any())).thenReturn(new Statistiques(
            List.of(new Statistiques.Annee(2023, 54822, 3203, 3398)), List.of("ONISR BAAC")));

        mvc.perform(get("/api/v1/accidents/stats/annual").param("mode", "road").with(role("analyst")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.years[0].fatalities").value(3398))
            .andExpect(jsonPath("$.sources[0]").value("ONISR BAAC"));

        ArgumentCaptor<Filtre> filtre = ArgumentCaptor.forClass(Filtre.class);
        verify(accidents).parAnnee(filtre.capture(), isNull());
        assertThat(filtre.getValue().mode()).isEqualTo("road");
    }

    @Test
    void exportCsvAvecEntete() throws Exception {
        mvc.perform(get("/api/v1/accidents/export.csv").with(role("analyst")))
            .andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith("text/csv"))
            .andExpect(content().string(org.hamcrest.Matchers.startsWith("id;date;heure_utc;mode;gravite")));
        verify(accidents).parcourir(any(), isNull(), any());
    }
}
