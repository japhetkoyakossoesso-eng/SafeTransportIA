package fr.safetransport.api.auth;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class CompteRepository {

    private static final String SQL = """
        SELECT u.id, u.username, i.password_hash,
               coalesce(array_agg(r.code ORDER BY r.code) FILTER (WHERE r.code IS NOT NULL), '{}') AS roles
        FROM core.users u
        JOIN sensitive.user_identities i ON i.user_id = u.id
        LEFT JOIN core.user_roles ur ON ur.user_id = u.id
        LEFT JOIN core.roles r ON r.id = ur.role_id
        WHERE u.username = ? AND u.is_active AND NOT u.is_service_account
        GROUP BY u.id, u.username, i.password_hash
        """;

    private final JdbcTemplate jdbc;

    public CompteRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<Compte> parNom(String username) {
        List<Compte> comptes = jdbc.query(SQL, (rs, i) -> new Compte(
            rs.getLong("id"),
            rs.getString("username"),
            rs.getString("password_hash"),
            Arrays.asList((String[]) rs.getArray("roles").getArray())), username);
        return comptes.stream().findFirst();
    }
}
