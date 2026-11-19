package fr.safetransport.api.source;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(SourceController.class)
class SourceControllerTest {

    @Autowired
    MockMvc mvc;

    @MockitoBean
    JdbcTemplate jdbc;

    @Test
    void listeLesSourcesSansLesSimulees() throws Exception {
        when(jdbc.queryForList(anyString(), eq(false)))
            .thenReturn(List.of(Map.of("code", "onisr_baac", "license", "Licence Ouverte / Open Licence (Etalab)")));

        mvc.perform(get("/api/v1/sources"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].code").value("onisr_baac"));

        verify(jdbc).queryForList(anyString(), eq(false));
    }

    @Test
    void inclutLesSimuleesSurDemande() throws Exception {
        when(jdbc.queryForList(anyString(), eq(true))).thenReturn(List.of());

        mvc.perform(get("/api/v1/sources").param("includeSimulated", "true"))
            .andExpect(status().isOk());

        verify(jdbc).queryForList(anyString(), eq(true));
    }
}
