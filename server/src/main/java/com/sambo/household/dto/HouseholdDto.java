package com.sambo.household.dto;

import com.sambo.household.Household;

import java.util.UUID;

public record HouseholdDto(UUID id, String name) {

    public static HouseholdDto from(Household h) {
        return new HouseholdDto(h.getId(), h.getName());
    }
}
