package com.sambo.household.dto;

import com.sambo.household.Household;

import java.util.UUID;

public record HouseholdDto(UUID id, String name, String avatarUrl) {

    public static HouseholdDto from(Household h, String avatarUrl) {
        return new HouseholdDto(h.getId(), h.getName(), avatarUrl);
    }
}
