-- Add a role column to app_user. Existing rows (none yet in dev, but harmless
-- if any) default to USER. The CHECK constraint mirrors the Role enum so the
-- DB rejects any value that the application doesn't know about — Hibernate's
-- @Enumerated(STRING) won't catch hand-edited rows.

ALTER TABLE app_user
    ADD COLUMN role TEXT NOT NULL DEFAULT 'USER';

ALTER TABLE app_user
    ADD CONSTRAINT chk_app_user_role CHECK (role IN ('ADMIN', 'USER'));
