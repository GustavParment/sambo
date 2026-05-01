package com.sambo.auth.config;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

/**
 * Bound from {@code sambo.jwt.*}. The signing secret MUST come from env / Secret
 * Manager in production — the YAML default is for local dev only.
 */
@Validated
@ConfigurationProperties(prefix = "sambo.jwt")
public record JwtProperties(

    /** Base64-encoded HMAC secret. Min 256 bits (44 base64 chars) for HS256. */
    @NotBlank String secret,

    @NotBlank String issuer,

    @NotBlank String audience,

    /** Access-token lifetime; refresh-token flow is a TODO. */
    @NotNull Duration accessTokenTtl
) {}
