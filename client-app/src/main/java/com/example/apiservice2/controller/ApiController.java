package com.example.apiservice2.controller;



import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClient;
import org.springframework.security.oauth2.client.annotation.RegisteredOAuth2AuthorizedClient;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.util.Map;

@Controller
@RequestMapping("/api")
public class ApiController {

    private static final Logger logger = LoggerFactory.getLogger(ApiController.class);

    private final WebClient webClient;

    @Value("${api-service-1.url:http://localhost:8083}")
    private String apiService1Url;

    public ApiController(WebClient webClient) {
        this.webClient = webClient;
    }

    @GetMapping("/delegate-call")
    public String delegateCall(@AuthenticationPrincipal OidcUser principal,
                               @RegisteredOAuth2AuthorizedClient("keycloak") OAuth2AuthorizedClient authorizedClient,
                               Model model) {

        logger.info("Making delegate call for user: {}", principal.getClaimAsString("preferred_username"));

        try {
            Map<String, Object> response = webClient
                    .get()
                    .uri(apiService1Url + "/api/delegate")
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block();

            model.addAttribute("success", true);
            model.addAttribute("response", response);
            model.addAttribute("username", principal.getClaimAsString("preferred_username"));

            logger.info("Delegate call successful");

        } catch (WebClientResponseException e) {
            logger.error("Delegate call failed with status: {}", e.getStatusCode(), e);
            model.addAttribute("error", true);
            model.addAttribute("errorMessage", "API call failed: " + e.getMessage());
            model.addAttribute("errorDetails", e.getResponseBodyAsString());
        } catch (Exception e) {
            logger.error("Unexpected error during delegate call", e);
            model.addAttribute("error", true);
            model.addAttribute("errorMessage", "Unexpected error: " + e.getMessage());
        }

        return "delegate-result";
    }

    @GetMapping("/profile")
    public String getProfile(@AuthenticationPrincipal OidcUser principal,
                             @RegisteredOAuth2AuthorizedClient("keycloak") OAuth2AuthorizedClient authorizedClient,
                             Model model) {

        logger.info("Getting profile for user: {}", principal.getClaimAsString("preferred_username"));

        try {
            Map<String, Object> response = webClient
                    .get()
                    .uri(apiService1Url + "/api/profile")
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block();

            model.addAttribute("success", true);
            model.addAttribute("response", response);
            model.addAttribute("username", principal.getClaimAsString("preferred_username"));

            logger.info("Profile call successful");

        } catch (WebClientResponseException e) {
            logger.error("Profile call failed with status: {}", e.getStatusCode(), e);
            model.addAttribute("error", true);
            model.addAttribute("errorMessage", "API call failed: " + e.getMessage());
            model.addAttribute("errorDetails", e.getResponseBodyAsString());
        } catch (Exception e) {
            logger.error("Unexpected error during profile call", e);
            model.addAttribute("error", true);
            model.addAttribute("errorMessage", "Unexpected error: " + e.getMessage());
        }

        return "profile-result";
    }
}
