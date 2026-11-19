package fr.safetransport.api.incident;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public record IncidentResume(UUID id, LocalDate date, OffsetDateTime occurredAt, String mode, String incidentClass,
                             String category, Integer minorInjuries, String summary, String country,
                             String municipality, String siteName, String source, String validationStatus,
                             boolean simulated, UUID escalatedToAccident) {
}
