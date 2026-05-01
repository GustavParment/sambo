package com.sambo.household.dto;

import com.sambo.auth.dto.AuthUserDto;

/**
 * Mirrors {@link com.sambo.auth.dto.LoginResponse} — accepting an invite moves
 * the user to a new household, so they need a fresh JWT (the old one carries
 * the wrong householdId/role).
 */
public record AcceptInviteResponse(
    String accessToken,
    AuthUserDto user
) {}
