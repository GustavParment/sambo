package com.sambo.auth.jwt;

import com.sambo.auth.config.JwtProperties;
import com.sambo.household.AppUser;
import com.sambo.household.HouseholdMembership;
import com.sambo.household.Role;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

/**
 * Issues and verifies the application's own HMAC-signed JWTs.
 * <p>
 * Token shape:
 * <pre>
 *   sub          = AppUser.id  (UUID)
 *   iss / aud    = configured in sambo.jwt.*
 *   iat / exp    = issued + access-token-ttl
 *   householdId  = UUID — the *active* household for this session. Switching
 *                  household issues a fresh JWT with a new value here.
 *   email        = denormalised for logging / convenience
 *   role         = "USER" | "ADMIN" — the user's role IN the active household
 *                  (per HouseholdMembership). A user can be ADMIN in one
 *                  household and USER in another; the claim follows the
 *                  active one.
 * </pre>
 *
 * The role lives in the *signed* payload, so a USER cannot self-promote to
 * ADMIN by editing the token — the signature breaks.
 */
@Service
public class JwtService {

    public static final String CLAIM_HOUSEHOLD = "householdId";
    public static final String CLAIM_EMAIL     = "email";
    public static final String CLAIM_ROLE      = "role";

    private final JwtProperties props;
    private final SecretKey key;

    public JwtService(JwtProperties props) {
        this.props = props;
        this.key   = Keys.hmacShaKeyFor(Decoders.BASE64.decode(props.secret()));
    }

    /**
     * Mint a JWT representing {@code user} authenticated into the given
     * {@code activeMembership}. The membership pins both the household and
     * the role baked into the token.
     */
    public String issue(AppUser user, HouseholdMembership activeMembership) {
        Instant now = Instant.now();
        return Jwts.builder()
            .subject(user.getId().toString())
            .issuer(props.issuer())
            .audience().add(props.audience()).and()
            .issuedAt(Date.from(now))
            .expiration(Date.from(now.plus(props.accessTokenTtl())))
            .claim(CLAIM_HOUSEHOLD, activeMembership.getHousehold().getId().toString())
            .claim(CLAIM_EMAIL, user.getEmail())
            .claim(CLAIM_ROLE, activeMembership.getRole().name())
            .signWith(key)
            .compact();
    }

    /**
     * @throws JwtException if the signature is invalid, the token is expired,
     *                      or the issuer/audience don't match.
     */
    public JwtClaims verify(String token) {
        Claims c = Jwts.parser()
            .verifyWith(key)
            .requireIssuer(props.issuer())
            .requireAudience(props.audience())
            .build()
            .parseSignedClaims(token)
            .getPayload();

        return new JwtClaims(
            UUID.fromString(c.getSubject()),
            UUID.fromString(c.get(CLAIM_HOUSEHOLD, String.class)),
            c.get(CLAIM_EMAIL, String.class),
            Role.valueOf(c.get(CLAIM_ROLE, String.class))
        );
    }
}
