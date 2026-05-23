package com.sambo.gcs;

import com.google.auth.oauth2.ServiceAccountCredentials;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.stereotype.Service;

import java.io.FileInputStream;
import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

/**
 * Resolves a GCS object key (e.g. "household-avatars/03.png") to a URL.
 * In prod it issues V4 signed URLs (1 h TTL) using a SA key file.
 * In dev it builds a plain emulator URL so no signing is needed.
 */
@Slf4j
@Service
@EnableConfigurationProperties(GcsProperties.class)
public class GcsStorageService {

    private static final long SIGNED_URL_TTL_HOURS = 1;

    private final GcsProperties props;
    private Storage storage;

    public GcsStorageService(GcsProperties props) {
        this.props = props;
    }

    @PostConstruct
    void init() throws IOException {
        if (!props.signUrls()) return;
        try (var stream = new FileInputStream(props.keyPath())) {
            var creds = ServiceAccountCredentials.fromStream(stream);
            storage = StorageOptions.newBuilder()
                .setCredentials(creds)
                .setProjectId(creds.getProjectId())
                .build()
                .getService();
        }
        log.info("GCS storage initialised (signed-urls=true, bucket={})", props.bucketName());
    }

    /** Returns null when avatarKey is null. */
    public String avatarUrl(String avatarKey) {
        if (avatarKey == null) return null;
        String objectName = "household-avatars/" + avatarKey + ".png";
        if (props.signUrls()) {
            return signedUrl(objectName);
        }
        return emulatorUrl(objectName);
    }

    private String signedUrl(String objectName) {
        BlobInfo blob = BlobInfo.newBuilder(
            BlobId.of(props.bucketName(), objectName)).build();
        return storage.signUrl(
            blob,
            SIGNED_URL_TTL_HOURS, TimeUnit.HOURS,
            Storage.SignUrlOption.withV4Signature()
        ).toString();
    }

    private String emulatorUrl(String objectName) {
        String encoded = URLEncoder.encode(objectName, StandardCharsets.UTF_8);
        return props.emulatorHost()
            + "/download/storage/v1/b/" + props.bucketName()
            + "/o/" + encoded + "?alt=media";
    }
}
