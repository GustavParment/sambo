package com.sambo.chore.dto;

import com.sambo.household.AppUser;

import java.util.UUID;

/**
 * Slim user reference for embedding in other DTOs (e.g. who completed a chore).
 * Mirrors what the client needs to render — id + display name, nothing more.
 */
public record UserSummaryDto(UUID id, String displayName) {

    public static UserSummaryDto from(AppUser u) {
        return new UserSummaryDto(u.getId(), u.getDisplayName());
    }
}
