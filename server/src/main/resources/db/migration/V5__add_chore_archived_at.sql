-- Soft-archive for chores. NULL = active and visible. Set = the chore is
-- hidden from the default list but its completion history (chore_completion)
-- is preserved untouched. Hard delete still exists for the rare "this row
-- was a typo, nuke it"-case.
--
-- Also backfilling chore.created_at — we never tracked when a chore was
-- created, but it's useful both for analytics and for sorting "newest first"
-- in the UI. Existing rows get now() as a best-effort default; it's wrong
-- but harmless and only matters for retrospective sorting.

ALTER TABLE chore
    ADD COLUMN archived_at TIMESTAMPTZ,
    ADD COLUMN created_at  TIMESTAMPTZ NOT NULL DEFAULT now();

-- Default list query is "WHERE archived_at IS NULL" — partial index makes
-- that the hot path even when many rows accumulate in archive over time.
CREATE INDEX idx_chore_active_per_household
    ON chore(household_id) WHERE archived_at IS NULL;
