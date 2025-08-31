package com.example.apiservice2.controller;



import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClient;
import org.springframework.security.oauth2.client.annotation.RegisteredOAuth2AuthorizedClient;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    @GetMapping("/")
    public String home() {
        return "index";
    }

    @GetMapping("/login")
    public String login() {
        return "login";
    }

    @GetMapping("/dashboard")
    public String dashboard(@AuthenticationPrincipal OidcUser principal,
                            @RegisteredOAuth2AuthorizedClient("keycloak") OAuth2AuthorizedClient authorizedClient,
                            Model model) {
        if (principal != null) {
            model.addAttribute("username", principal.getClaimAsString("preferred_username"));
            model.addAttribute("email", principal.getClaimAsString("email"));
            model.addAttribute("userId", principal.getClaimAsString("sub"));
            model.addAttribute("fullName", principal.getFullName());

            if (authorizedClient != null) {
                model.addAttribute("hasToken", true);
                model.addAttribute("clientName", authorizedClient.getClientRegistration().getClientName());
            }
        }
        return "dashboard";
    }
}
