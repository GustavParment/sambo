package com.sambo.household.dto;

import com.sambo.auth.dto.AuthUserDto;

/**
 * Response shape for any operation that mints a fresh JWT because the active
 * household changed (switch, leave, create). Mirrors {@link AcceptInviteResponse}
 * — kept separate so controllers don't conflate "joined a household via
 * invite" with "switched/created a household".
 */
public record HouseholdSessionResponse(
    String accessToken,
    AuthUserDto user
) {}
