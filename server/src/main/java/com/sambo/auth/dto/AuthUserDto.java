package com.sambo.auth.dto;

import com.sambo.household.AppUser;
import com.sambo.household.Role;

import java.util.UUID;

/**
 * The authenticated user's identity as returned to the client. Note that the
 * role is also baked into the signed JWT — the copy here is purely for the
 * client UI's convenience and is NOT what the server trusts for authorization.
 */
public record AuthUserDto(
    UUID id,
    UUID householdId,
    String email,
    String displayName,
    Role role
) {
    public static AuthUserDto from(AppUser u) {
        return new AuthUserDto(
            u.getId(),
            u.getHousehold().getId(),
            u.getEmail(),
            u.getDisplayName(),
            u.getRole()
        );
    }
}
