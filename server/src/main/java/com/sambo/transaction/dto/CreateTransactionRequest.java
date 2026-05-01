package com.sambo.transaction.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Manual transaction entry. Amount is positive for an expense (matches the
 * sign convention enforced on {@code bank_transaction.amount}).
 */
public record CreateTransactionRequest(
    @NotNull UUID categoryId,
    @NotNull @Positive BigDecimal amount,
    @NotBlank @Size(max = 128) String description,
    @NotNull LocalDate bookedDate
) {}
