package com.sambo.household.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateHouseholdAvatarRequest(
    @NotBlank String avatarKey
) {}
