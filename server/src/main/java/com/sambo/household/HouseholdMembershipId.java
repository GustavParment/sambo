package com.sambo.household;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

/**
 * Composite primary key for {@link HouseholdMembership}. JPA's @IdClass
 * requires field names matching the @Id-annotated fields on the entity
 * ({@code user} and {@code household}), holding the FK column type (UUID).
 */
public class HouseholdMembershipId implements Serializable {

    private UUID user;
    private UUID household;

    public HouseholdMembershipId() {}

    public HouseholdMembershipId(UUID user, UUID household) {
        this.user = user;
        this.household = household;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof HouseholdMembershipId that)) return false;
        return Objects.equals(user, that.user)
            && Objects.equals(household, that.household);
    }

    @Override
    public int hashCode() {
        return Objects.hash(user, household);
    }
}
