package com.sambo.household.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateHouseholdRequest(
    @NotBlank @Size(max = 60) String name
) {}
