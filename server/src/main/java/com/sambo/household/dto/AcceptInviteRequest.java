package com.sambo.household.dto;

import jakarta.validation.constraints.NotBlank;

public record AcceptInviteRequest(
    @NotBlank String code
) {}
