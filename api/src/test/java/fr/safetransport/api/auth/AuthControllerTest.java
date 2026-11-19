package fr.safetransport.api.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.jayway.jsonpath.JsonPath;

import fr.safetransport.api.common.Audit;
import fr.safetransport.api.security.SecurityConfig;

@WebMvcTest(AuthController.class)
@Import(SecurityConfig.class)
class AuthControllerTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JwtDecoder decodeur;

    @MockitoBean
    CompteRepository comptes;

    @MockitoBean
    Audit audit;

    static final Compte ANALYSTE = new Compte(2, "analyste.demo", new BCryptPasswordEncoder().encode("demo"),
        List.of("analyst"));

    static String corps(String user, String password) {
        return "{\"username\":\"" + user + "\",\"password\":\"" + password + "\"}";
    }

    @Test
    void connexionDonneUnJetonAvecLesRoles() throws Exception {
        when(comptes.parNom("analyste.demo")).thenReturn(Optional.of(ANALYSTE));

        String reponse = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(corps("analyste.demo", "demo")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.roles[0]").value("analyst"))
            .andReturn().getResponse().getContentAsString();

        Jwt jwt = decodeur.decode(JsonPath.read(reponse, "$.token"));
        assertThat(jwt.getSubject()).isEqualTo("analyste.demo");
        assertThat(jwt.getClaimAsStringList("roles")).containsExactly("analyst");
        verify(audit).connexion(2);
    }

    @Test
    void mauvaisMotDePasse401() throws Exception {
        when(comptes.parNom("analyste.demo")).thenReturn(Optional.of(ANALYSTE));
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(corps("analyste.demo", "faux")))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void compteInconnu401() throws Exception {
        when(comptes.parNom("personne")).thenReturn(Optional.empty());
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(corps("personne", "demo")))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void jetonFalsifieRefuse() throws Exception {
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/accidents")
                .header("Authorization", "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.abc"))
            .andExpect(status().isUnauthorized());
    }
}
