package com.sambo.household.dto;

import com.sambo.household.Invite;

import java.time.Instant;
import java.util.UUID;

public record InviteDto(UUID id, String code, Instant expiresAt) {

    public static InviteDto from(Invite i) {
        return new InviteDto(i.getId(), i.getCode(), i.getExpiresAt());
    }
}
