-- Multi-household memberships: a user can belong to multiple households.
--
-- Until now app_user.household_id implied 1:N (user → household). This
-- migration moves to M:N: app_user keeps an active_household_id (which one
-- you're "logged into right now"), and household_membership stores every
-- (user, household, role) tuple.
--
-- The role moves from app_user to household_membership — a user can be
-- ADMIN in household A and USER in household B.
--
-- Backfill: every existing user gets one membership pointing at their
-- current household with their current role. Then app_user.role is dropped
-- and app_user.household_id is renamed to active_household_id (and made
-- nullable so the "left all households" state is representable).

CREATE TABLE household_membership (
    user_id       UUID        NOT NULL REFERENCES app_user(id)  ON DELETE CASCADE,
    household_id  UUID        NOT NULL REFERENCES household(id) ON DELETE CASCADE,
    role          TEXT        NOT NULL DEFAULT 'USER'
                              CHECK (role IN ('USER', 'ADMIN')),
    joined_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, household_id)
);

CREATE INDEX idx_membership_user      ON household_membership(user_id);
CREATE INDEX idx_membership_household ON household_membership(household_id);

INSERT INTO household_membership (user_id, household_id, role, joined_at)
SELECT id, household_id, role, COALESCE(created_at, now())
FROM app_user;

ALTER TABLE app_user RENAME COLUMN household_id TO active_household_id;
ALTER TABLE app_user ALTER COLUMN active_household_id DROP NOT NULL;
ALTER TABLE app_user DROP COLUMN role;
