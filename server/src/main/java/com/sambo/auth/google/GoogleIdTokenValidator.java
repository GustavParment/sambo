package com.sambo.auth.google;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken.Payload;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.sambo.auth.config.GoogleAuthProperties;
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
@Component
public class GoogleIdTokenValidator {

    private final GoogleIdTokenVerifier verifier;

    public GoogleIdTokenValidator(GoogleAuthProperties props) {
        this.verifier = new GoogleIdTokenVerifier.Builder(
                new NetHttpTransport(),
                new GsonFactory()
            )
            .setAudience(props.audiences())
            .build();
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
                throw new InvalidGoogleTokenException("Google ID token is invalid or expired");
            }
            Payload payload = token.getPayload();
            if (!Boolean.TRUE.equals(payload.getEmailVerified())) {
                throw new InvalidGoogleTokenException("Google account email is not verified");
            }
            return new GoogleUserInfo(
                payload.getEmail(),
                payload.getSubject(),
                (String) payload.get("name")
            );
        } catch (GeneralSecurityException | IOException | IllegalArgumentException e) {
            // IllegalArgumentException comes from Google's Preconditions when the
            // input isn't even a well-formed JWT string (no dots, garbage, etc.).
            throw new InvalidGoogleTokenException("Failed to verify Google ID token", e);
        }
    }
}
