package fr.safetransport.api.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

import com.jayway.jsonpath.JsonPath;

// Lancé seulement avec API_TEST_DB=1 et une base migrée avec le jeu simulé (voir la CI)
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "API_TEST_DB", matches = "1")
class BaseReelleTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    String jeton(String username) throws Exception {
        String reponse = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"username\":\"" + username + "\",\"password\":\"demo\"}"))
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        return "Bearer " + JsonPath.read(reponse, "$.token");
    }

    @Test
    void parcoursComplet() throws Exception {
        String analyste = jeton("analyste.demo");

        String liste = mvc.perform(get("/api/v1/accidents").header("Authorization", analyste)
                .param("includeSimulated", "true").param("includeUnverified", "true").param("source", "sim_demo"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.total").value(2))
            .andReturn().getResponse().getContentAsString();
        String id = JsonPath.read(liste, "$.items[?(@.severity == 'serious')].id").toString()
            .replaceAll("[\\[\\]\"]", "");

        mvc.perform(get("/api/v1/accidents/" + id).header("Authorization", analyste))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.simulated").value(true))
            .andExpect(jsonPath("$.location.lat").isNumber())
            .andExpect(jsonPath("$.factors.length()").value(2));

        // Par défaut les données simulées sont cachées
        mvc.perform(get("/api/v1/accidents").header("Authorization", analyste).param("source", "sim_demo"))
            .andExpect(jsonPath("$.total").value(0));

        mvc.perform(get("/api/v1/incidents").header("Authorization", analyste)
                .param("includeSimulated", "true").param("includeUnverified", "true"))
            .andExpect(jsonPath("$.items[0].incidentClass").value("serious_incident"));

        mvc.perform(get("/api/v1/accidents").header("Authorization", jeton("declarant.demo")))
            .andExpect(status().isForbidden());

        mvc.perform(patch("/api/v1/accidents/" + id + "/validation").header("Authorization", analyste)
                .contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"validated\"}"))
            .andExpect(status().isForbidden());

        String responsable = jeton("resp.securite.demo");
        Long respId = jdbc.queryForObject("SELECT id FROM core.users WHERE username = 'resp.securite.demo'", Long.class);
        String avant = jdbc.queryForObject("SELECT validation_status::text FROM core.accidents WHERE public_id = ?::uuid",
            String.class, id);
        Long dernier = jdbc.queryForObject("SELECT coalesce(max(id), 0) FROM core.audit_logs", Long.class);
        try {
            mvc.perform(patch("/api/v1/accidents/" + id + "/validation").header("Authorization", responsable)
                    .contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"validated\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.validationStatus").value("validated"));

            Integer traces = jdbc.queryForObject("""
                SELECT count(*) FROM core.audit_logs l JOIN core.accidents a ON a.id = l.row_id
                WHERE l.id > ? AND l.table_name = 'core.accidents' AND l.action = 'UPDATE' AND l.actor_user_id = ?
                  AND a.public_id = ?::uuid AND l.new_data->>'validation_status' = 'validated'
                """, Integer.class, dernier, respId, id);
            assertThat(traces).isEqualTo(1);
        } finally {
            mvc.perform(patch("/api/v1/accidents/" + id + "/validation").header("Authorization", responsable)
                .contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"" + avant + "\"}"));
        }

        String csv = mvc.perform(get("/api/v1/accidents/export.csv").header("Authorization", analyste)
                .param("includeSimulated", "true").param("includeUnverified", "true").param("source", "sim_demo"))
            .andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        assertThat(csv.lines()).hasSize(3);
        assertThat(csv).doesNotContain("@example.org");
    }
}
