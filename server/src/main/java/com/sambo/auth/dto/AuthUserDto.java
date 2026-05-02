package com.sambo.auth.dto;

import com.sambo.household.AppUser;
import com.sambo.household.HouseholdMembership;
import com.sambo.household.Role;

import java.util.UUID;

/**
 * The authenticated user's identity as returned to the client. The role here
 * is the user's role in their currently *active* household — it follows the
 * active membership and changes when the user switches household. Server
 * trust comes from the signed JWT, not from this DTO.
 */
public record AuthUserDto(
    UUID id,
    UUID householdId,
    String email,
    String displayName,
    Role role
) {
    /**
     * @param activeMembership membership for {@code u.getActiveHousehold()};
     *                         caller is responsible for passing the right one.
     *                         May be null only if the user has no active
     *                         household yet.
     */
    public static AuthUserDto from(AppUser u, HouseholdMembership activeMembership) {
        return new AuthUserDto(
            u.getId(),
            activeMembership == null ? null : activeMembership.getHousehold().getId(),
            u.getEmail(),
            u.getDisplayName(),
            activeMembership == null ? null : activeMembership.getRole()
        );
    }
}
