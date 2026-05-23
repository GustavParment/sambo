package com.sambo.household.dto;

import com.sambo.household.HouseholdMembership;
import com.sambo.household.Role;

import java.time.Instant;
import java.util.UUID;

public record HouseholdMembershipDto(
    UUID householdId,
    String householdName,
    String householdAvatarUrl,
    Role role,
    Instant joinedAt,
    boolean active
) {
    public static HouseholdMembershipDto from(
        HouseholdMembership m, boolean active, String householdAvatarUrl
    ) {
        return new HouseholdMembershipDto(
            m.getHousehold().getId(),
            m.getHousehold().getName(),
            householdAvatarUrl,
            m.getRole(),
            m.getJoinedAt(),
            active
        );
    }
}
