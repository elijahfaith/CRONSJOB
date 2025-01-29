#!/bin/bash

# Define the timestamped filename
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_CSV="$(pwd)/dockerhub_logs_$timestamp.csv"

# Function to check if Docker Hub CLI is installed
check_dockerhub_cli() {
    echo "Checking if Docker Hub CLI is installed..."
    if ! command -v dockerhub &> /dev/null; then
        echo "Docker Hub CLI is not installed. Installing..."
        curl -L https://github.com/rofrischmann/docker-hub-cli/releases/latest/download/docker-hub-cli-linux -o dockerhub
        chmod +x dockerhub
        sudo mv dockerhub /usr/local/bin/

        if command -v dockerhub &> /dev/null; then
            echo "Docker Hub CLI successfully installed."
        else
            echo "Failed to install Docker Hub CLI. Please install it manually and re-run the script."
            exit 1
        fi
    else
        echo "Docker Hub CLI is already installed."
    fi
}

# Function to log in to Docker Hub
dockerhub_login() {
    echo "Logging in to Docker Hub..."
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
    if [ $? -eq 0 ]; then
        echo "Login successful."
    else
        echo "Login failed. Please check your credentials."
        exit 1
    fi
}

# Function to fetch Docker Hub logs and save them to CSV
monitor_logs() {
    echo "Fetching repositories..."
    REPOSITORIES=$(curl -s -H "Authorization: JWT ${DOCKER_TOKEN}" "https://hub.docker.com/v2/repositories/${DOCKER_USERNAME}/?page_size=100" | jq -r '.results|.[]|.name')

    if [ -z "$REPOSITORIES" ]; then
        echo "Error fetching repositories."
        exit 1
    fi

    echo "Repository,Tag Name,Last Pushed,Last Pulled,Architecture,Size (bytes)" > "$OUTPUT_CSV"

    while IFS= read -r REPO; do
        REPO_DETAILS=$(curl -s -H "Authorization: JWT ${DOCKER_TOKEN}" "https://hub.docker.com/v2/repositories/${DOCKER_USERNAME}/${REPO}/tags/?page_size=10")
        
        TAGS=$(echo "$REPO_DETAILS" | jq -r '.results[] | .name + "," + .tag_last_pushed + "," + .tag_last_pulled + "," + .images[0].architecture + "," + (.images[0].size|tostring)')
        
        while IFS= read -r TAG; do
            echo "$REPO,$TAG" >> "$OUTPUT_CSV"
        done <<< "$TAGS"

    done <<< "$REPOSITORIES"
}

# Run functions
check_dockerhub_cli
dockerhub_login
monitor_logs

echo "Log file saved: $OUTPUT_CSV"

# Ensure the file exists before sending email
if [ -f "$OUTPUT_CSV" ]; then
    echo "File '$OUTPUT_CSV' found. Proceeding to send email."
    python3 send_email.py "$OUTPUT_CSV"
else
    echo "Error: The file '$OUTPUT_CSV' does not exist."
    exit 1
fi
