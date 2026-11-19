package fr.safetransport.api;

import org.springframework.context.annotation.Configuration;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityScheme;

// Bouton « Authorize » dans /api/docs : coller le jeton reçu de /api/v1/auth/login
@Configuration
@OpenAPIDefinition(
    info = @Info(title = "SafeTransport AI : API métier", version = "0.1.0"),
    security = @SecurityRequirement(name = "jeton"))
@SecurityScheme(name = "jeton", type = SecuritySchemeType.HTTP, scheme = "bearer", bearerFormat = "JWT")
public class OpenApiConfig {
}
