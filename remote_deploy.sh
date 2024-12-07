#!/bin/bash

# Ask for remote machine details
read -p "Enter remote user: " REMOTE_USER
read -p "Enter remote host (IP or domain): " REMOTE_HOST
read -p "Enter remote directory (default is ~/remote): " REMOTE_DIR
REMOTE_DIR=${REMOTE_DIR:-remote}  # Default to 'remote' folder if not provided, without using ~

# Get the current working directory (the directory this script is executed from)
LOCAL_DIR=$(pwd)

# SSH command to run on the remote machine
SSH_CMD="ssh $REMOTE_USER@$REMOTE_HOST"

# Function to ensure the remote directory exists
ensure_remote_directory() {
    echo "Ensuring remote directory exists..."
    $SSH_CMD "mkdir -p $REMOTE_DIR"
}

# Function to copy the project directory to the remote machine
copy_project_to_remote() {
    echo "Copying project directory to remote machine..."
    # Copy the local directory to the remote machine
    scp -r "$LOCAL_DIR" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"
}

# Function to generate docker-compose.yml and run docker-compose on the remote machine
run_docker_compose() {
    # Generate docker-compose.yml and start the containers on the remote machine
    REMOTE_COMMANDS="
        cd $REMOTE_DIR/$(basename $LOCAL_DIR) || exit;
        # Assuming gen-docker-compose.sh is inside the project directory
        ./gen-docker-compose.sh && \
        docker-compose up -d --build
    "
    
    echo "Running docker-compose on the remote machine..."
    $SSH_CMD "$REMOTE_COMMANDS"
}

# Ensure the remote directory exists
ensure_remote_directory

# Copy the local project directory to the remote machine
copy_project_to_remote

# Run the Docker Compose setup on the remote machine
run_docker_compose

if [ $? -eq 0 ]; then
    echo "Deployment successful!"
else
    echo "Deployment failed."
fi
