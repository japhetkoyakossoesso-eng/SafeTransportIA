package fr.safetransport.api.common;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class Audit {

    private final JdbcTemplate jdbc;

    public Audit(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // Les triggers d'audit lisent ces réglages : à appeler au début d'une transaction qui modifie des faits
    public void auteur(Long userId) {
        jdbc.queryForList("SELECT set_config('app.user_id', ?, true), set_config('app.actor_type', 'user', true)",
            userId == null ? "" : userId.toString());
    }

    public void connexion(long userId) {
        jdbc.update("INSERT INTO core.audit_logs (actor_user_id, actor_type, action, table_name, row_id) "
            + "VALUES (?, 'user', 'LOGIN', 'core.users', ?)", userId, userId);
    }
}
