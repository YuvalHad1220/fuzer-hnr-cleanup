#!/bin/bash

# Define colors
BOLD_GREEN="\033[1;32m"  # Bold neon green
BOLD_BLUE="\033[1;34m"   # Bold blue
BOLD_RED="\033[1;31m"    # Bold red
BOLD_YELLOW="\033[1;33m" # Bold yellow
RESET="\033[0m"          # Reset to default

# Function to generate docker-compose.yml
generate_docker_compose() {
    # Project name (defaults to current directory name)
    PROJECT_NAME=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    
    # Choose network
    echo -e "${BOLD_BLUE}Available Docker Networks:${RESET}"
    docker network ls --format "{{.Name}}"
    echo -e "${BOLD_YELLOW}Enter the network you want to use (or press Enter for default 'bridge' network):${RESET}"
    read -p "> " NETWORK
    NETWORK=${NETWORK:-bridge}
    
    # Restart policy options
    echo -e "${BOLD_BLUE}Restart Policy Options:${RESET}"
    echo -e "1) ${BOLD_GREEN}unless-stopped (default)${RESET}"
    echo -e "2) ${BOLD_GREEN}always${RESET}"
    echo -e "3) ${BOLD_GREEN}on-failure${RESET}"
    echo -e "4) ${BOLD_GREEN}no${RESET}"
    echo -e "${BOLD_YELLOW}Choose restart policy (enter number):${RESET}"
    read -p "> " RESTART_CHOICE
    
    case $RESTART_CHOICE in
        2) RESTART_POLICY="always" ;;
        3) RESTART_POLICY="on-failure" ;;
        4) RESTART_POLICY="no" ;;
        *) RESTART_POLICY="unless-stopped" ;;
    esac
    
    # Port exposure
    echo -e "${BOLD_YELLOW}Do you want to expose a port? (y/n):${RESET}"
    read -p "> " EXPOSE_PORT
    
    if [[ $EXPOSE_PORT == "y" || $EXPOSE_PORT == "Y" ]]; then
        echo -e "${BOLD_BLUE}The container port is the port your application listens to inside the container.${RESET}"
        echo -e "${BOLD_BLUE}The host port is the port on your computer or server that maps to the container port.${RESET}"
        echo -e "${BOLD_YELLOW}Enter host port (default is 8080):${RESET}"
        read -p "> " HOST_PORT
        HOST_PORT=${HOST_PORT:-8080}
        echo -e "${BOLD_YELLOW}Enter container port (default is 8080):${RESET}"
        read -p "> " CONTAINER_PORT
        CONTAINER_PORT=${CONTAINER_PORT:-8080}
        
        PORT_MAPPING="      - \"${HOST_PORT}:${CONTAINER_PORT}\""
    else
        PORT_MAPPING=""
    fi
    
    # Generate docker-compose.yml
    cat > docker-compose.yml << EOL
version: '3.8'
services:
  ${PROJECT_NAME}:
    build: .
    container_name: ${PROJECT_NAME}
    restart: ${RESTART_POLICY}
    networks:
      - ${NETWORK}${PORT_MAPPING:+
    ports:
${PORT_MAPPING}}

networks:
  ${NETWORK}:
    external: true
EOL

    # Output summary
    echo -e "\n${BOLD_GREEN}--- Docker Compose Configuration ---${RESET}"
    echo -e "${BOLD_BLUE}Project Name:${RESET} ${PROJECT_NAME}"
    echo -e "${BOLD_BLUE}Network:${RESET} ${NETWORK}"
    echo -e "${BOLD_BLUE}Restart Policy:${RESET} ${RESTART_POLICY}"
    
    if [[ -n "$PORT_MAPPING" ]]; then
        echo -e "${BOLD_BLUE}Exposed Ports:${RESET} Host ${HOST_PORT}:Container ${CONTAINER_PORT}"
    else
        echo -e "${BOLD_BLUE}No ports exposed${RESET}"
    fi
    
    echo -e "\n${BOLD_BLUE}DNS Name for other containers on the ${NETWORK} network:${RESET}"
    echo -e "${BOLD_GREEN}${PROJECT_NAME}:${CONTAINER_PORT}${RESET}"

    if [[ -n "$PORT_MAPPING" ]]; then
        echo -e "${BOLD_BLUE}Access from host machine (using host port):${RESET}"
        echo -e "${BOLD_GREEN}localhost:${HOST_PORT}${RESET}"
    else
        echo -e "${BOLD_BLUE}No ports exposed for host access.${RESET}"
    fi
    echo -e "\n${BOLD_GREEN}Docker Compose file generated successfully!${RESET}"
}

# Check if docker-compose.yml already exists
if [ -f docker-compose.yml ]; then
    echo -e "${BOLD_RED}docker-compose.yml already exists.${RESET}"
    echo -e "${BOLD_YELLOW}Overwrite? (y/n):${RESET}"
    read -p "> " overwrite
    if [[ $overwrite == "y" || $overwrite == "Y" ]]; then
        # Force overwrite by calling the function
        > docker-compose.yml
        generate_docker_compose
    else
        echo -e "${BOLD_RED}Docker Compose generation cancelled.${RESET}"
        exit 1
    fi
else
    generate_docker_compose
fi
