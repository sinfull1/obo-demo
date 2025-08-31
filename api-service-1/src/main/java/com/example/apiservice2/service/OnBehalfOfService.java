package com.example.apiservice2.service;


import com.example.apiservice2.dto.TokenExchangeResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Service
public class OnBehalfOfService {

    private static final Logger logger = LoggerFactory.getLogger(OnBehalfOfService.class);

    private final WebClient webClient;

    @Value("${keycloak.url:http://localhost:8081}")
    private String keycloakUrl;

    @Value("${keycloak.client-id:api-service-1-client}")
    private String clientId;

    @Value("${keycloak.client-secret:api-service-1-secret}")
    private String clientSecret;

    @Value("${keycloak.realm:obo-demo-realm}")
    private String realm;

    public OnBehalfOfService(WebClient webClient) {
        this.webClient = webClient;
    }

    @Cacheable(value = "obo-tokens", key = "#userToken + '-' + #audience")
    public Mono<String> exchangeToken(String userToken, String audience) {
        logger.info("Performing token exchange for audience: {}", audience);

        String tokenEndpoint = keycloakUrl + "/realms/" + realm + "/protocol/openid-connect/token";

        MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
        formData.add("grant_type", "urn:ietf:params:oauth:grant-type:token-exchange");
        formData.add("client_id", clientId);
        formData.add("client_secret", clientSecret);
        formData.add("subject_token", userToken);
        formData.add("subject_token_type", "urn:ietf:params:oauth:token-type:access_token");
        formData.add("audience", audience);

        return webClient
                .post()
                .uri(tokenEndpoint)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(BodyInserters.fromFormData(formData))
                .retrieve()
                .onStatus(status -> !status.is2xxSuccessful(), response -> {
                    logger.error("Token exchange failed with status: {}", response.statusCode());
                    return response.bodyToMono(String.class)
                            .flatMap(errorBody -> {
                                logger.error("Error response: {}", errorBody);
                                return Mono.error(new RuntimeException("Token exchange failed: " + errorBody));
                            });
                })
                .bodyToMono(TokenExchangeResponse.class)
                .doOnSuccess(response -> logger.info("Token exchange successful"))
                .doOnError(error -> logger.error("Token exchange error", error))
                .map(TokenExchangeResponse::getAccessToken);
    }
}