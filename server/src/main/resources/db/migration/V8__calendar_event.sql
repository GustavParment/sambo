-- Shared household calendar — like Google Calendar, scoped to one household.
-- Every event has a creator (for "vem la in detta") and a colour the creator
-- picked when they made it.
--
-- Tider: starts_at and ends_at are TIMESTAMPTZ. all_day=true means the
-- client should ignore the time-of-day component and render across the
-- whole day; the timestamps are still stored (typically midnight on the
-- starts/ends day) so range queries stay simple.

CREATE TABLE calendar_event (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id         UUID NOT NULL REFERENCES household(id) ON DELETE CASCADE,
    created_by_user_id   UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    title                TEXT NOT NULL,
    description          TEXT,
    starts_at            TIMESTAMPTZ NOT NULL,
    ends_at              TIMESTAMPTZ NOT NULL,
    all_day              BOOLEAN NOT NULL DEFAULT FALSE,
    color                TEXT NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_event_range CHECK (ends_at >= starts_at),
    CONSTRAINT chk_event_color CHECK (color ~ '^#[0-9A-Fa-f]{6}$')
);

CREATE INDEX idx_event_household_starts ON calendar_event(household_id, starts_at);
CREATE INDEX idx_event_creator          ON calendar_event(created_by_user_id);
