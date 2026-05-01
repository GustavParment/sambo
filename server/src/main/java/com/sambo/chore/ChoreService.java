package com.sambo.chore;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.chore.dto.ChoreDto;
import com.sambo.household.AppUser;
import com.sambo.household.AppUserRepository;
import com.sambo.household.Household;
import com.sambo.household.HouseholdRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * All chore operations are scoped by the authenticated principal's household.
 * Mutations on a chore that doesn't belong to the caller's household raise
 * {@link AccessDeniedException} → 403, never silently succeed and never expose
 * the cross-tenant chore.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChoreService {

    private final ChoreRepository choreRepo;
    private final HouseholdRepository householdRepo;
    private final AppUserRepository userRepo;

    @Transactional(readOnly = true)
    public List<ChoreDto> listForHousehold(UUID householdId) {
        return choreRepo.findByHouseholdIdOrderByNameAsc(householdId).stream()
            .map(ChoreDto::from)
            .toList();
    }

    @Transactional
    public ChoreDto create(UUID householdId, String name) {
        Household household = householdRepo.getReferenceById(householdId);
        Chore saved = choreRepo.save(Chore.builder()
            .household(household)
            .name(name.trim())
            .build());
        log.info("Created chore '{}' in household={}", saved.getName(), householdId);
        return ChoreDto.from(saved);
    }

    @Transactional
    public ChoreDto complete(UUID choreId, SamboPrincipal principal) {
        Chore chore = loadOwned(choreId, principal.householdId());
        AppUser completer = userRepo.getReferenceById(principal.userId());
        chore.setLastCompletedAt(Instant.now());
        chore.setLastCompletedBy(completer);
        log.info("Chore {} completed by {}", choreId, principal.email());
        return ChoreDto.from(chore);
    }

    @Transactional
    public void delete(UUID choreId, UUID householdId) {
        Chore chore = loadOwned(choreId, householdId);
        choreRepo.delete(chore);
        log.info("Deleted chore {} from household {}", choreId, householdId);
    }

    private Chore loadOwned(UUID choreId, UUID householdId) {
        Chore chore = choreRepo.findById(choreId)
            .orElseThrow(() -> new EntityNotFoundException("Chore not found: " + choreId));
        if (!chore.getHousehold().getId().equals(householdId)) {
            // 403 not 404 — we *did* find it, we're just refusing.
            // (404 would leak existence; an attacker probing for valid ids
            // can already enumerate within their own household so neither
            // option is perfect, but 403 keeps the check honest.)
            throw new AccessDeniedException("Chore does not belong to your household");
        }
        return chore;
    }
}
