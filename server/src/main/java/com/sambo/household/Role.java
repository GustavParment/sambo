package com.sambo.household;

/**
 * Application-level role assigned to an {@link AppUser}.
 * <p>
 * Spring Security's {@code hasRole("ADMIN")} expects the authority string
 * {@code "ROLE_ADMIN"} — see {@link #authority()}.
 */
public enum Role {

    /** Full access; can manage household membership, categories, mappers. */
    ADMIN,

    /** Standard member of a household. */
    USER;

    /** Spring Security authority string, e.g. {@code "ROLE_ADMIN"}. */
    public String authority() {
        return "ROLE_" + name();
    }
}
