-- Multi-user chore-completion history.
--
-- Before: each chore stored a single (last_completed_at, last_completed_by) —
-- if both partners did it, only the last clicker got credit.
-- After: chore_completion is an append-only event log; each event can have
-- N participants via chore_completion_user. The chore.last_completed_at
-- column stays as a denormalised "newest event" timestamp for sorting and
-- "X days since" math (we don't want to scan the history on every list).

CREATE TABLE chore_completion (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chore_id      UUID NOT NULL REFERENCES chore(id) ON DELETE CASCADE,
    completed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_completion_chore_date
    ON chore_completion(chore_id, completed_at DESC);

CREATE TABLE chore_completion_user (
    completion_id UUID NOT NULL REFERENCES chore_completion(id) ON DELETE CASCADE,
    user_id       UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    PRIMARY KEY (completion_id, user_id)
);

CREATE INDEX idx_completion_user ON chore_completion_user(user_id);

-- Backfill existing single-user completions into the new tables so we don't
-- lose history when this migration runs against a populated dev DB.
DO $$
DECLARE
    c RECORD;
    new_completion_id UUID;
BEGIN
    FOR c IN
        SELECT id, last_completed_at, last_completed_by
        FROM chore
        WHERE last_completed_at IS NOT NULL AND last_completed_by IS NOT NULL
    LOOP
        INSERT INTO chore_completion (chore_id, completed_at)
        VALUES (c.id, c.last_completed_at)
        RETURNING id INTO new_completion_id;

        INSERT INTO chore_completion_user (completion_id, user_id)
        VALUES (new_completion_id, c.last_completed_by);
    END LOOP;
END $$;

-- The single-user FK is replaced by the join table — drop it.
ALTER TABLE chore DROP COLUMN last_completed_by;
