-- Schemaläggning — when this chore is next supposed to happen.
-- Distinct from last_completed_at (history) and from created_at (audit):
--   created_at      = when row was added
--   last_completed_at = newest event in chore_completion (history)
--   scheduled_for   = forward-looking deadline; UI flags overdue when
--                     scheduled_for < now AND last_completed_at < scheduled_for.

ALTER TABLE chore
    ADD COLUMN scheduled_for TIMESTAMPTZ;

CREATE INDEX idx_chore_household_scheduled
    ON chore(household_id, scheduled_for)
    WHERE archived_at IS NULL AND scheduled_for IS NOT NULL;
