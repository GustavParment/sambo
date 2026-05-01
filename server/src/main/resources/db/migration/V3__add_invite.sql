-- Invitation codes for joining an existing household.
--
-- An ADMIN of a household generates a short code (6 chars, ambiguous chars
-- excluded) and shares it via SMS / Signal / whatever. The recipient — who is
-- already logged in (Google) and currently sits in their own auto-bootstrapped
-- household — POSTs the code to /api/invites/accept and is moved to the
-- inviter's household with role=USER. Their old (necessarily empty) household
-- is deleted in the same transaction.

CREATE TABLE invite (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id  UUID NOT NULL REFERENCES household(id) ON DELETE CASCADE,
    code          VARCHAR(16) NOT NULL UNIQUE,
    created_by    UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at    TIMESTAMPTZ NOT NULL,
    used_at       TIMESTAMPTZ,
    used_by       UUID REFERENCES app_user(id) ON DELETE SET NULL
);

-- Lookup is always by code, usually filtering for un-used. Partial index
-- keeps the hot path tiny even after lots of historic invites.
CREATE INDEX idx_invite_active_code ON invite(code) WHERE used_at IS NULL;
CREATE INDEX idx_invite_household   ON invite(household_id);
