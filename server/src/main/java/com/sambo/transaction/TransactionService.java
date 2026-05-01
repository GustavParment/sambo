package com.sambo.transaction;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.budget.HouseholdCategory;
import com.sambo.budget.HouseholdCategoryRepository;
import com.sambo.household.AppUser;
import com.sambo.household.AppUserRepository;
import com.sambo.household.Household;
import com.sambo.household.HouseholdRepository;
import com.sambo.transaction.dto.TransactionDto;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TransactionService {

    private final BankTransactionRepository txRepo;
    private final HouseholdCategoryRepository categoryRepo;
    private final HouseholdRepository householdRepo;
    private final AppUserRepository userRepo;

    @Transactional
    public TransactionDto createManual(
        SamboPrincipal principal,
        UUID categoryId,
        BigDecimal amount,
        String description,
        LocalDate bookedDate
    ) {
        UUID householdId = principal.householdId();
        HouseholdCategory category = loadOwnedCategory(categoryId, householdId);
        Household household = householdRepo.getReferenceById(householdId);
        AppUser createdBy = userRepo.findById(principal.userId())
            .orElseThrow(() -> new EntityNotFoundException("User not found: " + principal.userId()));

        BankTransaction saved = txRepo.save(BankTransaction.builder()
            .household(household)
            .category(category)
            .amount(amount)
            .description(description.trim())
            .bookedDate(bookedDate)
            .source(TransactionSource.MANUAL)
            .createdBy(createdBy)
            .build());

        return TransactionDto.from(saved);
    }

    @Transactional(readOnly = true)
    public List<TransactionDto> listForMonth(UUID householdId, YearMonth ym, UUID categoryId) {
        LocalDate first = ym.atDay(1);
        LocalDate last  = ym.atEndOfMonth();
        List<BankTransaction> rows = (categoryId == null)
            ? txRepo.findByHouseholdIdAndBookedDateBetweenOrderByBookedDateDescCreatedAtDesc(
                householdId, first, last)
            : txRepo.findByHouseholdIdAndCategoryIdAndBookedDateBetweenOrderByBookedDateDescCreatedAtDesc(
                householdId, categoryId, first, last);
        return rows.stream().map(TransactionDto::from).toList();
    }

    @Transactional
    public void delete(UUID transactionId, UUID householdId) {
        BankTransaction tx = txRepo.findById(transactionId)
            .orElseThrow(() -> new EntityNotFoundException("Transaction not found: " + transactionId));
        if (!tx.getHousehold().getId().equals(householdId)) {
            throw new AccessDeniedException("Transaction does not belong to your household");
        }
        txRepo.delete(tx);
    }

    private HouseholdCategory loadOwnedCategory(UUID categoryId, UUID householdId) {
        HouseholdCategory cat = categoryRepo.findById(categoryId)
            .orElseThrow(() -> new EntityNotFoundException("Category not found: " + categoryId));
        if (!cat.getHousehold().getId().equals(householdId)) {
            throw new AccessDeniedException("Category does not belong to your household");
        }
        return cat;
    }
}
