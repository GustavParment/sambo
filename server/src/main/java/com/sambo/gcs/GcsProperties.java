package com.sambo.gcs;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "sambo.gcs")
public record GcsProperties(
    String bucketName,
    boolean signUrls,
    String keyPath,
    String emulatorHost
) {}
