package com.sambo.auth.config;

import jakarta.validation.constraints.NotEmpty;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.util.List;

/**
 * Bound from {@code sambo.google.*}. {@link #audiences()} are the Google OAuth
 * client IDs we accept — typically the iOS + Android client IDs from Google
 * Cloud Console. ID tokens whose {@code aud} claim isn't in this list are rejected.
 */
@Validated
@ConfigurationProperties(prefix = "sambo.google")
public record GoogleAuthProperties(

    @NotEmpty List<String> audiences
) {}
