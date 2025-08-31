package com.example.apiservice2.controller;



import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class SecureDataController {

    @GetMapping("/data")
    public ResponseEntity<Map<String, Object>> getSecureData(@AuthenticationPrincipal Jwt jwt) {
        Map<String, Object> response = new HashMap<>();

        // Extract key claims from the JWT

        response.put("secure_data", Map.of(
                "account_balance", "$10,000.00",
                "ssn_last_four", "1234",
                "credit_score", 750,
                "accessed_at", Instant.now()
        ));

        response.put("service", "api-service-2");
        response.put("message", "This is secure data from API Service 2");

        return ResponseEntity.ok(response);
    }
}
