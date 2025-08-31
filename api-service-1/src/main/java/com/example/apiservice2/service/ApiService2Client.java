package com.example.apiservice2.service;


import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Service
public class ApiService2Client {

    private static final Logger logger = LoggerFactory.getLogger(ApiService2Client.class);

    private final WebClient webClient;

    @Value("${api-service-2.url:http://localhost:8082}")
    private String apiService2Url;

    public ApiService2Client(WebClient webClient) {
        this.webClient = webClient;
    }

    public Mono<String> callSecureDataEndpoint(String accessToken) {
        logger.info("Calling API Service 2 secure data endpoint");

        return webClient
                .get()
                .uri(apiService2Url + "/api/data")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                .retrieve()
                .onStatus(status -> !status.is2xxSuccessful(), response -> {
                    logger.error("API Service 2 call failed with status: {}", response.statusCode());
                    return response.bodyToMono(String.class)
                            .flatMap(errorBody -> {
                                logger.error("Error response: {}", errorBody);
                                return Mono.error(new RuntimeException("API Service 2 call failed: " + errorBody));
                            });
                })
                .bodyToMono(String.class);
    }
}