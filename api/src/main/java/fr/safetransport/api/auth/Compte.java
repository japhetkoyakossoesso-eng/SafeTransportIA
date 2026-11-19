package fr.safetransport.api.auth;

import java.util.List;

public record Compte(long id, String username, String passwordHash, List<String> roles) {
}
