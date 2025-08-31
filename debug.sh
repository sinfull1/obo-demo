#!/bin/bash
# debug-exchanged-token.sh - Debug why API Service 2 rejects the exchanged token

echo "🔍 OAuth 2.0 Exchanged Token Validation Debug Tool"
echo "=================================================="

KEYCLOAK_URL="http://localhost:8081"
API_SERVICE_2_URL="http://localhost:8082"
REALM="obo-demo-realm"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${BLUE}📋 $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Step 1: Get original user token (Token A)
print_step "Step 1: Getting original user token (Token A)..."
TOKEN_A_RESPONSE=$(curl -s \
  -d "client_id=client-app-client" \
  -d "username=adminuser" \
  -d "password=poll" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token")

TOKEN_A=$(echo "$TOKEN_A_RESPONSE" | jq -r '.access_token // empty' 2>/dev/null)

if [ -z "$TOKEN_A" ] || [ "$TOKEN_A" = "null" ]; then
    print_error "Failed to get Token A"
    echo "Response: $TOKEN_A_RESPONSE"
    exit 1
fi

print_success "Token A obtained"

# Step 2: Perform token exchange (Token A → Token B)
print_step "Step 2: Performing token exchange (Token A → Token B)..."
TOKEN_EXCHANGE_RESPONSE=$(curl -s \
  -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
  -d "client_id=api-service-1-client" \
  -d "client_secret=api-service-1-secret" \
  -d "subject_token=$TOKEN_A" \
  -d "subject_token_type=urn:ietf:params:oauth:token-type:access_token" \
  -d "audience=api-service-2-client" \
  "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token")

TOKEN_B=$(echo "$TOKEN_EXCHANGE_RESPONSE" | jq -r '.access_token // empty' 2>/dev/null)

if [ -z "$TOKEN_B" ] || [ "$TOKEN_B" = "null" ]; then
    print_error "Token exchange failed"
    echo "Response: $TOKEN_EXCHANGE_RESPONSE"
    exit 1
fi

print_success "Token B obtained (exchanged token)"

# Step 3: Analyze both tokens
print_step "Step 3: Analyzing token structures..."

echo ""
echo "🔍 TOKEN A (Original) Analysis:"
echo "=============================="
if command -v jq &> /dev/null; then
    # Decode Token A (you'll need to paste this into jwt.io for full analysis)
    echo "Token A Header + Payload (decode at jwt.io):"
    echo "$TOKEN_A" | cut -d'.' -f1-2 | tr '.' '\n' | while read part; do
        echo "  $part" | base64 -d 2>/dev/null | jq . 2>/dev/null || echo "  (base64 padding issues - use jwt.io)"
    done
    echo ""
    echo "Key fields to check at jwt.io:"
    echo "- aud (audience): Should include 'api-service-1-client'"
    echo "- azp (authorized party): Should be 'client-app-client'"
    echo "- realm_access.roles: Should include user roles"
fi

echo ""
echo "🔍 TOKEN B (Exchanged) Analysis:"
echo "==============================="
if command -v jq &> /dev/null; then
    echo "Token B Header + Payload (decode at jwt.io):"
    echo "$TOKEN_B" | cut -d'.' -f1-2 | tr '.' '\n' | while read part; do
        echo "  $part" | base64 -d 2>/dev/null | jq . 2>/dev/null || echo "  (base64 padding issues - use jwt.io)"
    done
    echo ""
    echo "Key fields to check at jwt.io:"
    echo "- aud (audience): Should be ['api-service-2-client']"
    echo "- azp (authorized party): Should be 'api-service-1-client'"
    echo "- realm_access.roles: Should preserve original user roles"
    echo "- sub (subject): Should match Token A (same user)"
fi

# Step 4: Test Token B directly against API Service 2
print_step "Step 4: Testing Token B directly against API Service 2..."

API2_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
  -H "Authorization: Bearer $TOKEN_B" \
  "$API_SERVICE_2_URL/api/data")

HTTP_CODE=$(echo $API2_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
RESPONSE_BODY=$(echo $API2_RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')

echo "HTTP Status: $HTTP_CODE"
echo "Response Body:"
echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

if [ "$HTTP_CODE" = "200" ]; then
    print_success "✅ Token B works directly with API Service 2!"
    echo "The issue might be in API Service 1's handling, not the token itself."
elif [ "$HTTP_CODE" = "401" ]; then
    print_error "❌ Token B authentication failed"
    echo ""
    echo "🔍 Possible causes:"
    echo "1. Token signature validation failed"
    echo "2. Token expired"
    echo "3. JWKS URL connectivity issues"
    echo ""
    echo "🔧 Debug steps:"
    echo "- Check API Service 2 logs: docker-compose logs api-service-2"
    echo "- Verify JWKS URL: curl $KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/certs"
    echo "- Check token expiration at jwt.io"
elif [ "$HTTP_CODE" = "403" ]; then
    print_error "❌ Token B authorization failed"
    echo ""
    echo "🔍 Possible causes:"
    echo "1. Missing or incorrect roles in Token B"
    echo "2. Audience validation failed"
    echo "3. Custom authorization logic failed"
    echo ""
    echo "🔧 Debug steps:"
    echo "- Decode Token B at jwt.io and check realm_access.roles"
    echo "- Verify audience is 'api-service-2-client'"
    echo "- Check API Service 2 security configuration"
else
    print_error "❌ Unexpected HTTP status: $HTTP_CODE"
fi

# Step 5: Test JWKS connectivity from API Service 2's perspective
print_step "Step 5: Testing JWKS connectivity..."

JWKS_RESPONSE=$(curl -s "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/certs")
if echo "$JWKS_RESPONSE" | jq -e '.keys' > /dev/null 2>&1; then
    print_success "JWKS endpoint accessible"
    KEYS_COUNT=$(echo "$JWKS_RESPONSE" | jq '.keys | length')
    echo "Available signing keys: $KEYS_COUNT"
else
    print_error "JWKS endpoint not accessible"
    echo "Response: $JWKS_RESPONSE"
fi

# Test from API Service 2 container's perspective
print_step "Testing JWKS from API Service 2 container..."
CONTAINER_JWKS=$(docker-compose exec -T api-service-2 curl -s http://keycloak:8080/realms/$REALM/protocol/openid-connect/certs 2>/dev/null)
if echo "$CONTAINER_JWKS" | jq -e '.keys' > /dev/null 2>&1; then
    print_success "JWKS accessible from API Service 2 container"
else
    print_warning "JWKS not accessible from API Service 2 container"
    echo "This could explain signature validation failures"
fi

echo ""
print_step "📊 Summary & Next Steps:"
echo "========================"
echo "1. Token Exchange: ✅ Working"
echo "2. Token B Generation: ✅ Working"
echo "3. Token B Validation: $(if [ "$HTTP_CODE" = "200" ]; then echo '✅ Working'; else echo '❌ Failed'; fi)"

echo ""
echo "🔧 Common Fixes:"
echo "1. If 401 (Unauthorized):"
echo "   - Check JWKS connectivity: ./fix-jwks-connectivity.sh"
echo "   - Verify token signature validation"
echo ""
echo "2. If 403 (Forbidden):"
echo "   - Check Token B roles: Decode at jwt.io"
echo "   - Verify API Service 2 role requirements"
echo "   - Check audience claim in Token B"
echo ""
echo "3. View detailed logs:"
echo "   - API Service 2: docker-compose logs -f api-service-2"
echo "   - All services: docker-compose logs -f"
echo ""
echo "🌐 Useful Tools:"
echo "- Decode tokens: https://jwt.io"
echo "- This script output: Copy Token A and Token B to jwt.io for detailed analysis"