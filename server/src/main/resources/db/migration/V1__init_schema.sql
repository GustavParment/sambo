-- ============================================================================
-- Sambo MVP — initial schema
--
-- Convention: bank_transaction.amount is POSITIVE for an expense (outflow) and
-- NEGATIVE for income/refund. The Tink ingest layer is responsible for
-- inverting the bank's native sign so all downstream budget math is additive.
--
-- Multi-tenancy: every row that is not a Household itself carries household_id
-- (directly or transitively). Application code MUST filter every query by
-- household_id of the authenticated user.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------- households & users ---------------------------------------------

CREATE TABLE household (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE app_user (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id  UUID NOT NULL REFERENCES household(id) ON DELETE CASCADE,
    email         TEXT NOT NULL UNIQUE,
    display_name  TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_app_user_household ON app_user(household_id);

-- ---------- budget domain ---------------------------------------------------

CREATE TABLE household_category (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id  UUID NOT NULL REFERENCES household(id) ON DELETE CASCADE,
    name          TEXT NOT NULL,
    sort_order    INT  NOT NULL DEFAULT 0,
    UNIQUE (household_id, name)
);

CREATE TABLE budget_period (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id  UUID NOT NULL REFERENCES household(id) ON DELETE CASCADE,
    year          INT  NOT NULL,
    month         INT  NOT NULL CHECK (month BETWEEN 1 AND 12),
    UNIQUE (household_id, year, month)
);

CREATE TABLE budget_allocation (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id        UUID NOT NULL REFERENCES budget_period(id) ON DELETE CASCADE,
    category_id      UUID NOT NULL REFERENCES household_category(id) ON DELETE CASCADE,
    budgeted_amount  NUMERIC(12,2) NOT NULL,
    UNIQUE (period_id, category_id)
);

-- ---------- transactions ----------------------------------------------------

CREATE TABLE bank_transaction (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id          UUID NOT NULL REFERENCES household(id) ON DELETE CASCADE,
    tink_transaction_id   TEXT NOT NULL UNIQUE,
    booked_date           DATE NOT NULL,
    amount                NUMERIC(12,2) NOT NULL,
    description           TEXT NOT NULL,
    category_id           UUID REFERENCES household_category(id) ON DELETE SET NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tx_household_date ON bank_transaction(household_id, booked_date);
CREATE INDEX idx_tx_category       ON bank_transaction(category_id);

CREATE TABLE category_mapper (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id  UUID NOT NULL REFERENCES household(id) ON DELETE CASCADE,
    keyword       TEXT NOT NULL,
    category_id   UUID NOT NULL REFERENCES household_category(id) ON DELETE CASCADE,
    UNIQUE (household_id, keyword)
);

-- ---------- chores ----------------------------------------------------------

CREATE TABLE chore (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id        UUID NOT NULL REFERENCES household(id) ON DELETE CASCADE,
    name                TEXT NOT NULL,
    last_completed_at   TIMESTAMPTZ,
    last_completed_by   UUID REFERENCES app_user(id) ON DELETE SET NULL
);

CREATE INDEX idx_chore_household ON chore(household_id);

-- ---------- tink credentials ------------------------------------------------

CREATE TABLE tink_credential (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                    UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    access_token_ciphertext    TEXT NOT NULL,
    refresh_token_ciphertext   TEXT NOT NULL,
    expires_at                 TIMESTAMPTZ NOT NULL,
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tink_credential_user ON tink_credential(user_id);

-- ============================================================================
-- v_budget_category_status
--
-- One row per (period, category) with budgeted / spent / remaining already
-- aggregated. Spent comes from bank_transaction rows whose booked_date falls
-- in the period's calendar month and whose category matches.
--
-- Uncategorised transactions (category_id IS NULL) intentionally fall outside
-- every category bucket — they're surfaced separately so the UI can prompt the
-- user to categorise them.
-- ============================================================================

CREATE OR REPLACE VIEW v_budget_category_status AS
SELECT
    ba.id                                                          AS allocation_id,
    bp.id                                                          AS period_id,
    bp.household_id                                                AS household_id,
    bp.year                                                        AS year,
    bp.month                                                       AS month,
    hc.id                                                          AS category_id,
    hc.name                                                        AS category_name,
    hc.sort_order                                                  AS sort_order,
    ba.budgeted_amount                                             AS budgeted_amount,
    COALESCE(SUM(t.amount), 0)::NUMERIC(12,2)                      AS spent_amount,
    (ba.budgeted_amount - COALESCE(SUM(t.amount), 0))::NUMERIC(12,2) AS remaining_amount
FROM budget_allocation ba
JOIN budget_period      bp ON bp.id = ba.period_id
JOIN household_category hc ON hc.id = ba.category_id
LEFT JOIN bank_transaction t
       ON t.category_id  = hc.id
      AND t.household_id = bp.household_id
      AND EXTRACT(YEAR  FROM t.booked_date) = bp.year
      AND EXTRACT(MONTH FROM t.booked_date) = bp.month
GROUP BY ba.id, bp.id, bp.household_id, bp.year, bp.month,
         hc.id, hc.name, hc.sort_order, ba.budgeted_amount;
