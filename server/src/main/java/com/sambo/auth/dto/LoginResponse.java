package com.sambo.auth.dto;

public record LoginResponse(
    String accessToken,
    AuthUserDto user
) {}
