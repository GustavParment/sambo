package com.sambo.household.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record SwitchHouseholdRequest(
    @NotNull UUID householdId
) {}
