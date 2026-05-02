package com.sambo.household.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record LeaveHouseholdRequest(
    @NotNull UUID householdId
) {}
