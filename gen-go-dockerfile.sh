#!/bin/bash

# Function to generate Dockerfile
generate_dockerfile() {
    # Default project name to current directory name
    PROJECT_NAME=$(basename "$PWD")

    # Check if go.mod exists
    if [ ! -f go.mod ]; then
        echo "go.mod not found. Initializing Go module..."
        go mod init "${PROJECT_NAME}"
    fi

    # Ensure dependencies are downloaded and go.sum is created
    go mod tidy

    # Create Dockerfile
    cat > Dockerfile << EOL
# Use Go 1.23 as the base image
FROM golang:1.23

# Set timezone to Jerusalem
ENV TZ=Asia/Jerusalem
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set working directory inside the container
WORKDIR /app

# Copy go mod and sum files (use || true to handle potential missing go.sum)
COPY go.mod go.sum* ./

# Download Go module dependencies
RUN go mod download

# Copy the source code into the container
COPY . .

# Build the application
RUN go build -o ${PROJECT_NAME} .

# Command to run the executable
CMD ["./${PROJECT_NAME}"]
EOL

    echo "Dockerfile generated successfully for project: ${PROJECT_NAME}"
}

# Check if Dockerfile already exists
if [ -f Dockerfile ]; then
    read -p "Dockerfile already exists. Overwrite? (y/n): " overwrite
    if [[ $overwrite == "y" || $overwrite == "Y" ]]; then
        generate_dockerfile
    else
        echo "Dockerfile generation cancelled."
        exit 1
    fi
else
    generate_dockerfile
fi