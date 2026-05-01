package com.sambo.transaction;

import com.sambo.budget.HouseholdCategory;
import com.sambo.household.AppUser;
import com.sambo.household.Household;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * A single transaction against the household's shared budget — either pulled
 * from Tink ({@code source=TINK}, {@code tinkTransactionId} populated, no
 * {@code createdBy}) or manually entered by a user
 * ({@code source=MANUAL}, no {@code tinkTransactionId}, {@code createdBy} set).
 *
 * <p>Sign convention: {@code amount} is positive for an expense (outflow) and
 * negative for income/refund.
 */
@Entity
@Table(
    name = "bank_transaction",
    uniqueConstraints = @UniqueConstraint(columnNames = "tink_transaction_id"),
    indexes = {
        @Index(name = "idx_tx_household_date", columnList = "household_id, booked_date"),
        @Index(name = "idx_tx_category", columnList = "category_id"),
        @Index(name = "idx_tx_created_by", columnList = "created_by_user_id")
    }
)
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor @Builder
public class BankTransaction {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "household_id", nullable = false)
    private Household household;

    /** External id from Tink — used for idempotent upserts. Null for manual rows. */
    @Column(name = "tink_transaction_id")
    private String tinkTransactionId;

    @Column(name = "booked_date", nullable = false)
    private LocalDate bookedDate;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(nullable = false)
    private String description;

    /** Null until categorisation runs (or if no rule matches). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    private HouseholdCategory category;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private TransactionSource source;

    /** Who keyed in a MANUAL row. Null for TINK rows. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_user_id")
    private AppUser createdBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
        if (source == null) source = TransactionSource.TINK;
    }
}
