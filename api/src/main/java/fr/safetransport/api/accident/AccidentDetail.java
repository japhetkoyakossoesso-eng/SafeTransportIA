package fr.safetransport.api.accident;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record AccidentDetail(UUID id, LocalDate date, OffsetDateTime occurredAt, String mode, String category,
                             String severity, String severityLabel, Integer fatalities, Integer seriousInjuries,
                             Integer minorInjuries, String summary, Lieu location, Source source,
                             String confidence, String validationStatus, OffsetDateTime validatedAt,
                             boolean simulated, List<Facteur> factors) {

    public record Lieu(Double lat, Double lon, String precision, String country, String region,
                       String department, String municipality, String inseeCode, String siteName) {
    }

    public record Source(String code, String name, String license, String sourceRef, Long importJobId) {
    }

    // assertion : established (fait établi), probable ou hypothesis
    public record Facteur(String category, String code, String description, String assertion,
                          String confidence, String statedBy) {
    }
}
