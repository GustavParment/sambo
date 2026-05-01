package com.sambo.budget.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;

public record UpsertAllocationRequest(
    @NotNull @PositiveOrZero BigDecimal amount
) {}
