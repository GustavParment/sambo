package com.sambo.household.dto;

/**
 * Body for PATCH /api/user/me. avatarColor is a 7-char hex string (#RRGGBB)
 * or null to reset to the default.
 */
public record UpdateAvatarColorRequest(String avatarColor) {}
