#!/bin/bash

# Local path where CSV file will be saved
OUTPUT_DIR=$(dirname "$OUTPUT_CSV")
# mkdir -p "$OUTPUT_DIR"
OUTPUT_CSV="./dockerhub_logs.csv"  # Change this to your desired path

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")


# Function to check if Docker Hub CLI is installed
check_dockerhub_cli() {
    echo "Checking if Docker Hub CLI is installed..."
    if ! command -v dockerhub &> /dev/null; then
        echo "Docker Hub CLI is not installed. Installing..."
        
        # Install Docker Hub CLI
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

# Function to log in to Docker Hub using Docker Hub CLI
dockerhub_login() {
    echo "Logging in to Docker Hub..."
    
    # Use the environment variables for username and password
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
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
        echo "Repository,Tag Name,Last Pushed,Last Pulled,Architecture,Size (bytes)" > "$OUTPUT_CSV"  # Create the file and add headers
    else
        echo "Appending to existing log file."
    fi

    echo "Fetching repositories..."

    # Fetch list of repositories for the user using the Docker Hub API
    REPOSITORIES=$(curl -s -H "Authorization: JWT ${DOCKER_TOKEN}" https://hub.docker.com/v2/repositories/${DOCKER_USERNAME}/?page_size=100 | jq -r '.results|.[]|.name')

    # Check if fetching repositories was successful
    if [ $? -ne 0 ]; then
        echo "Error fetching repositories. Please ensure Docker Hub CLI is configured properly."
        exit 1
    fi

    echo "Repositories found: "
    echo "$REPOSITORIES"

    # Loop through each repository and fetch its log details via API
    echo "Fetching log details for each repository..."
    while IFS= read -r REPO; do
        echo "Logs for repository: $REPO"
        
        # Get repository details using the Docker Hub API (replace with appropriate endpoint)
        REPO_DETAILS=$(curl -s -H "Authorization: JWT ${DOCKER_TOKEN}" https://hub.docker.com/v2/repositories/${DOCKER_USERNAME}/${REPO}/tags/?page_size=10)

        # Debug: Print the raw response from the API to check what's returned
        echo "Raw API response for $REPO: $REPO_DETAILS"

        # Check if the response is empty or invalid
        if [ -z "$REPO_DETAILS" ] || [ "$REPO_DETAILS" == "null" ]; then
            echo "No log details found for repository $REPO"
            continue
        fi

        # Extract the tag details (name, last pushed, last pulled, etc.) from the API response
        TAGS=$(echo "$REPO_DETAILS" | jq -r '.results[] | .name + "," + .tag_last_pushed + "," + .tag_last_pulled + "," + .images[0].architecture + "," + (.images[0].size|tostring)')

        # Loop through tags and save the details to the CSV
        while IFS= read -r TAG; do
            # Append the repository and its tag details to the CSV file
            echo "$REPO,$TAG" >> "$OUTPUT_CSV"
        done <<< "$TAGS"

        echo "-----------------------------------"
    done <<< "$REPOSITORIES"
}



# Main script execution
check_dockerhub_cli    # Check if Docker Hub CLI is installed and install it if necessary
dockerhub_login        # Log in to Docker Hub using Docker Hub CLI
monitor_logs           # Run the monitoring process and save output to CSV

echo "OUTPUT_CSV path: $OUTPUT_CSV"


if [ ! -f "$OUTPUT_CSV" ]; then
    echo "Error: The file '$OUTPUT_CSV' does not exist."
    exit 1
else
    echo "File '$OUTPUT_CSV' found. Proceeding to send email."
fi

#defining the new file name
OUTPUT_CSV="$(pwd)/dockerhub_logs_$timestamp.csv"

# Rename the existing file
mv "$(pwd)/dockerhub_logs.csv" "$OUTPUT_CSV"

# Call the Python script with the renamed file
python3 send_email.py "$OUTPUT_CSV"

