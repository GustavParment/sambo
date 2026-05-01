package com.sambo.transaction.dto;

import com.sambo.transaction.BankTransaction;
import com.sambo.transaction.TransactionSource;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record TransactionDto(
    UUID id,
    UUID categoryId,
    String categoryName,
    BigDecimal amount,
    String description,
    LocalDate bookedDate,
    TransactionSource source,
    UUID createdByUserId,
    String createdByName,
    Instant createdAt
) {
    public static TransactionDto from(BankTransaction t) {
        return new TransactionDto(
            t.getId(),
            t.getCategory() != null ? t.getCategory().getId() : null,
            t.getCategory() != null ? t.getCategory().getName() : null,
            t.getAmount(),
            t.getDescription(),
            t.getBookedDate(),
            t.getSource(),
            t.getCreatedBy() != null ? t.getCreatedBy().getId() : null,
            t.getCreatedBy() != null ? t.getCreatedBy().getDisplayName() : null,
            t.getCreatedAt()
        );
    }
}
