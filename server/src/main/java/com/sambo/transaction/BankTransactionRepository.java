package com.sambo.transaction;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BankTransactionRepository extends JpaRepository<BankTransaction, UUID> {

    Optional<BankTransaction> findByTinkTransactionId(String tinkTransactionId);

    List<BankTransaction> findByHouseholdIdAndBookedDateBetween(
        UUID householdId, LocalDate from, LocalDate toInclusive
    );

    List<BankTransaction> findByHouseholdIdAndCategoryIsNull(UUID householdId);

    List<BankTransaction> findByHouseholdIdAndCategoryIdAndBookedDateBetweenOrderByBookedDateDescCreatedAtDesc(
        UUID householdId, UUID categoryId, LocalDate from, LocalDate toInclusive
    );

    List<BankTransaction> findByHouseholdIdAndBookedDateBetweenOrderByBookedDateDescCreatedAtDesc(
        UUID householdId, LocalDate from, LocalDate toInclusive
    );
}
