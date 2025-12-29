#!/bin/bash

# Ensure JSON files exist to prevent Docker from creating them as directories
if [ ! -f tokens.json ]; then
    echo "{}" > tokens.json
fi

if [ ! -f oauth.json ]; then
    echo "{}" > oauth.json
fi

if [ ! -f header_auth.json ]; then
    echo "{}" > header_auth.json
fi

# Check if .env exists
if [ ! -f .env ]; then
    echo "Warning: .env file missing! Please create it with your credentials."
    exit 1
fi

# Build and start the container
docker compose up -d --build

echo "Deployment finished! Application should be running on port 80."
