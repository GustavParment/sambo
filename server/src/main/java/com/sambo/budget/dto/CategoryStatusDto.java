package com.sambo.budget.dto;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * One category line in the monthly budget overview. Shaped to be consumed
 * directly by the Flutter client — no further math needed on the client.
 *
 * @param utilization fraction in [0, +∞), where 1.0 = fully spent. Capped client-side.
 */
public record CategoryStatusDto(
    UUID categoryId,
    String categoryName,
    BigDecimal budgeted,
    BigDecimal spent,
    BigDecimal remaining,
    BigDecimal utilization
) {}
