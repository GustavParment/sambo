package com.sambo.transaction;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.transaction.dto.CreateTransactionRequest;
import com.sambo.transaction.dto.TransactionDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

/**
 * Transactions live under {@code /api/budget/transactions} so the client only
 * needs to know one base path for everything in the budget tab.
 */
@RestController
@RequestMapping("/api/budget/transactions")
@RequiredArgsConstructor
public class TransactionController {

    private final TransactionService transactionService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TransactionDto create(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody CreateTransactionRequest req
    ) {
        return transactionService.createManual(
            principal,
            req.categoryId(),
            req.amount(),
            req.description(),
            req.bookedDate()
        );
    }

    /** GET /api/budget/transactions?yearMonth=2026-05[&categoryId=...] */
    @GetMapping
    public List<TransactionDto> list(
        @AuthenticationPrincipal SamboPrincipal principal,
        @RequestParam @DateTimeFormat(pattern = "yyyy-MM") YearMonth yearMonth,
        @RequestParam(required = false) UUID categoryId
    ) {
        return transactionService.listForMonth(principal.householdId(), yearMonth, categoryId);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable UUID id
    ) {
        transactionService.delete(id, principal.householdId());
    }
}
