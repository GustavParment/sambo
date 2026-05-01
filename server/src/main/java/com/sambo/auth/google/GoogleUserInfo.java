package com.sambo.auth.google;

/**
 * Subset of Google ID-token payload we care about.
 *
 * @param email Google account email — used as the local key for {@code app_user}.
 * @param subject opaque, stable Google user id (the {@code sub} claim).
 * @param name human display name (may be null if the user denied profile scope).
 */
public record GoogleUserInfo(String email, String subject, String name) {}
