package com.sambo.budget.dto;

import java.util.UUID;

import com.sambo.budget.HouseholdCategory;

public record CategoryDto(
    UUID id,
    String name,
    int sortOrder

) {
    public static CategoryDto from(HouseholdCategory c) {
        return new CategoryDto(c.getId(), c.getName(), c.getSortOrder());
    }
}
