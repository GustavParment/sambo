package com.sambo.household;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface InviteRepository extends JpaRepository<Invite, UUID> {

    Optional<Invite> findByCode(String code);

    Optional<Invite> findByCodeAndUsedAtIsNull(String code);
}
