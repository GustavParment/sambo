-- Manual transaction entry — bridge until Tink integration ships.
--
-- bank_transaction was modelled around Tink ingest only:
--   * tink_transaction_id was NOT NULL UNIQUE (used for idempotent upserts)
--   * no notion of who entered the row (Tink had no person to attribute it to)
--
-- For manual entries we need both relaxed: tink_transaction_id becomes
-- nullable (UNIQUE still holds — Postgres allows multiple NULLs), and a
-- source discriminator + created-by user link are added.

ALTER TABLE bank_transaction
    ALTER COLUMN tink_transaction_id DROP NOT NULL;

ALTER TABLE bank_transaction
    ADD COLUMN source TEXT NOT NULL DEFAULT 'TINK'
        CHECK (source IN ('TINK', 'MANUAL'));

ALTER TABLE bank_transaction
    ADD COLUMN created_by_user_id UUID
        REFERENCES app_user(id) ON DELETE SET NULL;

CREATE INDEX idx_tx_created_by ON bank_transaction(created_by_user_id);

-- A MANUAL row must have a creator; a TINK row must not (Tink has no user).
-- Enforced as a single CHECK so violations surface from the DB regardless of
-- which code path inserts.
ALTER TABLE bank_transaction
    ADD CONSTRAINT chk_tx_source_creator CHECK (
        (source = 'MANUAL' AND created_by_user_id IS NOT NULL)
        OR (source = 'TINK' AND created_by_user_id IS NULL)
    );
