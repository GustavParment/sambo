package com.sambo.chore;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface ChoreCompletionRepository extends JpaRepository<ChoreCompletion, UUID> {

    Optional<ChoreCompletion> findFirstByChoreIdOrderByCompletedAtDesc(UUID choreId);
}
