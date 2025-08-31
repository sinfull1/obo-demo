package com.example.apiservice2.controller;

import com.example.apiservice2.service.ApiService2Client;
import com.example.apiservice2.service.OnBehalfOfService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ProfileController {

    private static final Logger logger = LoggerFactory.getLogger(ProfileController.class);

    private final OnBehalfOfService onBehalfOfService;
    private final ApiService2Client apiService2Client;

    public ProfileController(OnBehalfOfService onBehalfOfService, ApiService2Client apiService2Client) {
        this.onBehalfOfService = onBehalfOfService;
        this.apiService2Client = apiService2Client;
    }

    @GetMapping("/delegate")
    public Mono<ResponseEntity<Map<String, Object>>> delegateCall(@AuthenticationPrincipal Jwt jwt) {
        logger.info("Received delegate call for user: {}", jwt.getClaimAsString("preferred_username"));

        String userToken = jwt.getTokenValue();
        String audience = "api-service-2-client";

        return onBehalfOfService.exchangeToken(userToken, audience)
                .flatMap(apiService2Client::callSecureDataEndpoint)
                .map(secureData -> {
                    Map<String, Object> response = new HashMap<>();
                    response.put("service", "api-service-1");
                    response.put("message", "Successfully delegated call to API Service 2");
                    response.put("user", jwt.getClaimAsString("preferred_username"));
                    response.put("processed_at", Instant.now());
                    response.put("original_token_azp", jwt.getClaimAsString("azp"));
                    response.put("secure_data_from_api_service_2", secureData);

                    return ResponseEntity.ok(response);
                })
                .doOnError(error -> logger.error("Error in delegate call", error))
                .onErrorReturn(ResponseEntity.internalServerError()
                        .body(Map.of("error", "Failed to process delegate call")));
    }

    @GetMapping("/profile")
    public ResponseEntity<Map<String, Object>> getProfile(@AuthenticationPrincipal Jwt jwt) {
        Map<String, Object> response = new HashMap<>();
        response.put("service", "api-service-1");
        response.put("user_id", jwt.getClaimAsString("sub"));
        response.put("username", jwt.getClaimAsString("preferred_username"));
        response.put("email", jwt.getClaimAsString("email"));
        response.put("roles", jwt.getClaim("realm_access"));
        response.put("message", "This is profile data from API Service 1");

        return ResponseEntity.ok(response);
    }
}