package com.sambo.tink;

import com.sambo.household.AppUser;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Per-user Tink OAuth credentials. Tokens MUST be encrypted at rest before being
 * stored — see {@link TinkService} (TODO: wire up envelope encryption / KMS).
 */
@Entity
@Table(name = "tink_credential")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class TinkCredential {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(name = "access_token_ciphertext", nullable = false, length = 2048)
    private String accessTokenCiphertext;

    @Column(name = "refresh_token_ciphertext", nullable = false, length = 2048)
    private String refreshTokenCiphertext;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist @PreUpdate
    void touch() {
        updatedAt = Instant.now();
    }
}
