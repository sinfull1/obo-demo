echo "Building OAuth 2.0 On-Behalf-Of Flow Demo..."

# Function to check if directory exists and has pom.xml
build_service() {
    local service_name=$1
    local service_dir=$2

    if [ -d "$service_dir" ] && [ -f "$service_dir/pom.xml" ]; then
        echo "Building $service_name..."
        cd "$service_dir"
        mvn clean package -DskipTests -q
        if [ $? -eq 0 ]; then
            echo "✅ $service_name built successfully"
        else
            echo "❌ Failed to build $service_name"
            exit 1
        fi
        cd ..
    else
        echo "⚠️  Skipping $service_name - directory or pom.xml not found"
    fi
}

# Build each service
build_service "API Service 2" "api-service-2"
build_service "API Service 1" "api-service-1"
build_service "Client App" "client-app"

echo ""
echo "🎉 All services built successfully!"
echo "Run './startup.sh' to start the complete system."

## Keycloak Setup Script (setup-keycloak.sh)
#!/bin/bash

# This script sets up additional Keycloak configuration that can't be easily exported
# Run this after Keycloak is up and running

KEYCLOAK_URL="http://localhost:8081"
REALM="obo-demo-realm"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin"

echo "Setting up Keycloak configuration..."

# Get admin token
ADMIN_TOKEN=$(curl -s \
  -d "client_id=admin-cli" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASSWORD" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | \
  grep -o '"access_token":"[^"]*' | \
  cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
  echo "Failed to get admin token"
  exit 1
fi

echo "Admin token obtained"

# Get service account user ID for api-service-1-client
SERVICE_ACCOUNT_ID=$(curl -s \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients" | \
  grep -A 20 '"clientId":"api-service-1-client"' | \
  grep '"id"' | head -1 | \
  grep -o '"[^"]*"' | tail -1 | \
  tr -d '"')

if [ -z "$SERVICE_ACCOUNT_ID" ]; then
  echo "Failed to get service account client ID"
  exit 1
fi

echo "Service account client ID: $SERVICE_ACCOUNT_ID"

# Get service account user
SERVICE_USER_ID=$(curl -s \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients/$SERVICE_ACCOUNT_ID/service-account-user" | \
  grep -o '"id":"[^"]*' | \
  cut -d'"' -f4)

if [ -z "$SERVICE_USER_ID" ]; then
  echo "Failed to get service account user ID"
  exit 1
fi

echo "Service account user ID: $SERVICE_USER_ID"

# Get realm-management client ID
REALM_MANAGEMENT_ID=$(curl -s \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients" | \
  grep -A 20 '"clientId":"realm-management"' | \
  grep '"id"' | head -1 | \
  grep -o '"[^"]*"' | tail -1 | \
  tr -d '"')

if [ -z "$REALM_MANAGEMENT_ID" ]; then
  echo "Failed to get realm-management client ID"
  exit 1
fi

echo "Realm management client ID: $REALM_MANAGEMENT_ID"

# Get impersonation role ID
IMPERSONATION_ROLE_ID=$(curl -s \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients/$REALM_MANAGEMENT_ID/roles" | \
  grep -A 5 '"name":"impersonation"' | \
  grep '"id"' | \
  grep -o '"[^"]*"' | tail -1 | \
  tr -d '"')

if [ -z "$IMPERSONATION_ROLE_ID" ]; then
  echo "Failed to get impersonation role ID"
  exit 1
fi

echo "Impersonation role ID: $IMPERSONATION_ROLE_ID"

# Assign impersonation role to service account
curl -s \
  -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "[{\"id\":\"$IMPERSONATION_ROLE_ID\",\"name\":\"impersonation\"}]" \
  "$KEYCLOAK_URL/admin/realms/$REALM/users/$SERVICE_USER_ID/role-mappings/clients/$REALM_MANAGEMENT_ID"

echo "Impersonation role assigned to api-service-1-client service account"

# Verify the setup
echo "Verifying setup..."

# Check if impersonation role is assigned
ROLES=$(curl -s \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$KEYCLOAK_URL/admin/realms/$REALM/users/$SERVICE_USER_ID/role-mappings/clients/$REALM_MANAGEMENT_ID")

if echo "$ROLES" | grep -q "impersonation"; then
  echo "✅ Setup successful! Impersonation role is properly assigned."
else
  echo "❌ Setup failed! Impersonation role assignment verification failed."
  echo "Roles found: $ROLES"
  exit 1
fi

echo "Keycloak setup completed successfully!"

## Testing Script (test-flow.sh)
#!/bin/bash

# Test the OAuth 2.0 On-Behalf-Of flow manually via curl

KEYCLOAK_URL="http://localhost:8081"
CLIENT_APP_URL="http://localhost:8080"
API_SERVICE_1_URL="http://localhost:8083"
API_SERVICE_2_URL="http://localhost:8082"
REALM="obo-demo-realm"

echo "Testing OAuth 2.0 On-Behalf-Of Flow..."

# Step 1: Get user token (simulating what the client app would do)
echo "Step 1: Getting user access token..."

USER_TOKEN=$(curl -s \
  -d "client_id=client-app-client" \
  -d "username=testuser" \
  -d "password=testpassword" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" | \
  grep -o '"access_token":"[^"]*' | \
  cut -d'"' -f4)

if [ -z "$USER_TOKEN" ]; then
  echo "❌ Failed to get user token"
  exit 1
fi

echo "✅ User token obtained"

# Step 2: Call API Service 1 with user token
echo "Step 2: Calling API Service 1..."

API1_RESPONSE=$(curl -s \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$API_SERVICE_1_URL/api/delegate")

if echo "$API1_RESPONSE" | grep -q "error"; then
  echo "❌ API Service 1 call failed:"
  echo "$API1_RESPONSE"
  exit 1
fi

echo "✅ API Service 1 response:"
echo "$API1_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$API1_RESPONSE"

# Verify the response contains data from API Service 2
if echo "$API1_RESPONSE" | grep -q "api-service-2"; then
  echo "✅ On-Behalf-Of flow completed successfully!"
  echo "✅ Response contains data from API Service 2"
else
  echo "❌ Response doesn't contain expected data from API Service 2"
  exit 1
fi

echo ""
echo "🎉 All tests passed! The OAuth 2.0 On-Behalf-Of flow is working correctly."