#!/bin/bash

# Docker Hub credentials
source .env

# Local path where CSV file will be saved
OUTPUT_CSV="./dockerhub_logs.csv"  # Change this to your desired path
OUTPUT_DIR=$(dirname "$OUTPUT_CSV")

# Function to check if Docker Hub CLI is installed
check_dockerhub_cli() {
    echo "Checking if Docker Hub CLI is installed..."
    if ! command -v dockerhub &> /dev/null; then
        echo "Docker Hub CLI is not installed. Installing..."
        
        # Install Docker Hub CLI
        curl -L https://github.com/rofrischmann/docker-hub-cli/releases/latest/download/docker-hub-cli-linux -o dockerhub
        chmod +x dockerhub
        mv dockerhub /usr/local/bin/

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
    echo "$DOCKERHUB_PASSWORD" | dockerhub login -u "$DOCKERHUB_USERNAME" --password-stdin
    if [ $? -eq 0 ]; then
        echo "Login successful."
    else
        echo "Login failed. Please check your credentials."
        exit 1
    fi
}

# Function to monitor repository logs and save them to CSV
monitor_logs() {
    # Create the folder if it doesn't exist
    mkdir -p "$OUTPUT_DIR"

    # Create the CSV file and add a header if it doesn't exist
    if [ ! -f "$OUTPUT_CSV" ]; then
        echo "Repository,Log Details" > "$OUTPUT_CSV"  # Create the file and add headers
    else
        echo "Appending to existing log file."
    fi

    echo "Fetching repositories..."

    # Fetch list of repositories for the user
    REPOSITORIES=$(dockerhub repos list --format '{{.Name}}')

    # Check if fetching repositories was successful
    if [ $? -ne 0 ]; then
        echo "Error fetching repositories. Please ensure Docker Hub CLI is configured properly."
        exit 1
    fi

    echo "Repositories found: "
    echo "$REPOSITORIES"

    # Loop through each repository and fetch its log details
    echo "Fetching log details for each repository..."
    while IFS= read -r REPO; do
        echo "Logs for repository: $REPO"
        
        # Get details for the specific repository and format with jq
        LOG_DETAILS=$(dockerhub repos get "$DOCKERHUB_USERNAME/$REPO" | jq -r '.')
        
        # Escape double quotes and commas for CSV formatting
        LOG_DETAILS=$(echo "$LOG_DETAILS" | sed 's/"/""/g' | sed 's/,/;/g')

        # Append the repository and its log details to the CSV file
        echo "$REPO,\"$LOG_DETAILS\"" >> "$OUTPUT_CSV"
        echo "-----------------------------------"
    done <<< "$REPOSITORIES"
}


check_dockerhub_cli    # Check if Docker Hub CLI is installed and install it if necessary
dockerhub_login        # Log in to Docker Hub
monitor_logs           # Run the monitoring process and save output to CSV
