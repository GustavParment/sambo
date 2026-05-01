package com.sambo.auth.jwt;

import com.sambo.household.Role;

import java.util.UUID;

/**
 * Decoded claims after a successful JWT verification — what the rest of the app
 * sees as the authenticated principal's identity.
 */
public record JwtClaims(
    UUID userId,
    UUID householdId,
    String email,
    Role role
) {}
