package com.sambo.auth.jwt;

import com.sambo.household.Role;

import java.util.UUID;

/**
 * The authenticated principal sitting on every request after
 * {@link JwtAuthenticationFilter} runs. Available via
 * {@code SecurityContextHolder.getContext().getAuthentication().getPrincipal()}.
 *
 * <p>Use this — never the request path / body / headers — as the authoritative
 * source of {@code householdId} and {@code role} for any tenant or role check.
 */
public record SamboPrincipal(
    UUID userId,
    UUID householdId,
    String email,
    Role role
) {
    public static SamboPrincipal from(JwtClaims c) {
        return new SamboPrincipal(c.userId(), c.householdId(), c.email(), c.role());
    }
}
