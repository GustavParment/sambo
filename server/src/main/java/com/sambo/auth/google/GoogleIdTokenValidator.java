package com.sambo.auth.google;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken.Payload;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.sambo.auth.config.GoogleAuthProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.security.GeneralSecurityException;

/**
 * Validates ID tokens issued to our Flutter clients by Google.
 * <p>
 * Trust is anchored on Google's public JWKS (fetched and cached by
 * {@link GoogleIdTokenVerifier}) plus an {@code aud} check against the OAuth
 * client IDs configured in {@link GoogleAuthProperties}. A token whose
 * audience isn't in that list is rejected — that's how we ensure the token was
 * minted for *our* app, not some other Google project.
 */
@Slf4j
@Component
public class GoogleIdTokenValidator {

    private final GoogleIdTokenVerifier verifier;
    private final GoogleAuthProperties props;

    public GoogleIdTokenValidator(GoogleAuthProperties props) {
        this.props = props;
        this.verifier = new GoogleIdTokenVerifier.Builder(
                new NetHttpTransport(),
                new GsonFactory()
            )
            .setAudience(props.audiences())
            .build();
        log.info("GoogleIdTokenValidator configured with audiences={}", props.audiences());
    }

    /**
     * @return the validated user info if the token is well-formed, signed by
     *         Google, unexpired, and addressed to one of our audiences.
     * @throws InvalidGoogleTokenException otherwise.
     */
    public GoogleUserInfo validate(String idTokenString) {
        try {
            GoogleIdToken token = verifier.verify(idTokenString);
            if (token == null) {
                // Most common reasons: signature, expiry, or aud mismatch.
                // Try to decode the payload anyway so we can log which.
                Payload p = tryParsePayload(idTokenString);
                if (p != null) {
                    log.warn("Google ID token rejected. token.aud={} token.iss={} token.exp={} expected.audiences={}",
                        p.getAudience(), p.getIssuer(), p.getExpirationTimeSeconds(), props.audiences());
                } else {
                    log.warn("Google ID token rejected (unparseable payload). expected.audiences={}", props.audiences());
                }
                throw new InvalidGoogleTokenException("Google ID token is invalid or expired");
            }
            Payload payload = token.getPayload();
            if (!Boolean.TRUE.equals(payload.getEmailVerified())) {
                log.warn("Google ID token rejected: email not verified. email={} email_verified={}",
                    payload.getEmail(), payload.getEmailVerified());
                throw new InvalidGoogleTokenException("Google account email is not verified");
            }
            log.debug("Google ID token verified ok. email={} sub={} aud={}",
                payload.getEmail(), payload.getSubject(), payload.getAudience());
            return new GoogleUserInfo(
                payload.getEmail(),
                payload.getSubject(),
                (String) payload.get("name")
            );
        } catch (GeneralSecurityException | IOException | IllegalArgumentException e) {
            log.warn("Google ID token verification threw {}: {}", e.getClass().getSimpleName(), e.getMessage());
            throw new InvalidGoogleTokenException("Failed to verify Google ID token", e);
        }
    }

    /** Best-effort payload decode for diagnostic logging only — does NOT verify signature. */
    private static Payload tryParsePayload(String idTokenString) {
        try {
            return GoogleIdToken.parse(new GsonFactory(), idTokenString).getPayload();
        } catch (IOException | IllegalArgumentException ignored) {
            return null;
        }
    }
}
