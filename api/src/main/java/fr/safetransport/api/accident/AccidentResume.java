package fr.safetransport.api.accident;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public record AccidentResume(UUID id, LocalDate date, OffsetDateTime occurredAt, String mode, String severity,
                             String severityLabel, Integer fatalities, Integer seriousInjuries,
                             Integer minorInjuries, String country, String department, String municipality,
                             String source, String validationStatus, boolean simulated) {
}
