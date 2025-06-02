#!/bin/bash
set -euo pipefail

# Terminal formatting constants
BOLD=$(tput bold)
RESET=$(tput sgr0)
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"

SCRIPT_DIR_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Dynamic script importing function - recursively finds and sources scripts from a base directory
import_scripts() {
  local base_dir="$1"
  shift
  local scripts_to_import=("$@")

  for script_name in "${scripts_to_import[@]}"; do
    # Find script file recursively inside base_dir
    local found_file
    found_file=$(find "$base_dir" -type f -name "$script_name" -print -quit)

    if [[ -z "$found_file" ]]; then
      echo "Error: Script '$script_name' not found in $base_dir" >&2
      exit 1
    fi

    # Source the found script
    if ! source "$found_file"; then
      echo "Error: Failed to source '$found_file'" >&2
      exit 1
    fi
  done
}

# Import the menu system from the scripts directory
import_scripts "$SCRIPT_DIR_ABS/../scripts" menu.sh

# Project configuration paths and settings
PROJECT_DIR=$SCRIPT_DIR_ABS
ENV_FILE="$PROJECT_DIR/.env"
AZTEC_DATA_DIR="$PROJECT_DIR/data/aztec"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
USEFUL_PORTS="40400 8080"

# Create directory structure
mkdir -p "$PROJECT_DIR" "$AZTEC_DATA_DIR"
## mkdir -p "$(dirname "$JWT_FILE")"

# Initialize environment file with default configuration if it doesn't exist
if [[ ! -f "$ENV_FILE" ]]; then
  # If the file does not exist, create and add content
  cat <<EOF >"$ENV_FILE"
## Press Ctrl+S to save, then Ctrl+X to exit
#
# Aztec Node Configuration
# Refer to Aztec documentation for details on these variables.

VALIDATOR_PRIVATE_KEY=
VALIDATOR_PUBLIC_ADDRESS=
P2P_IP=
ETHEREUM_HOSTS=
L1_CONSENSUS_HOST_URLS=

# Default ports, can be overridden if necessary
TCP_UDP_PORT=40400
HTTP_PORT=8080

#  Additional arguments, flags and options can be passed to the entrypoint
EXTRA_ARGS=""

#
#
## Press Ctrl+S, then Ctrl+X to save and exit
EOF
fi

# Load environment variables if the file exists
if [[ -f "$ENV_FILE" ]]; then
  source $ENV_FILE
fi

# Register custom menu items for specialized Aztec operations
register_menu_item "[10] Fetch L2 Block + Sync Proof" show_l2_block_and_sync_proof
register_menu_item "[11] Retrieve Sequencer PeerId" get_sequencer_peer_id_from_logs
register_menu_item "[12] Display Public IP Address" fetch_ip

# Generate Docker Compose configuration dynamically based on environment variables
setup_compose_file() {
  cat >"$COMPOSE_FILE" <<EOF
services:
  aztec:
    image: aztecprotocol/aztec:alpha-testnet
    container_name: aztec
    environment:
      ETHEREUM_HOSTS: "${ETHEREUM_HOSTS}"
      L1_CONSENSUS_HOST_URLS: "${L1_CONSENSUS_HOST_URLS}"
      DATA_DIRECTORY: "/data"
      VALIDATOR_PRIVATE_KEY: "${VALIDATOR_PRIVATE_KEY}"

      P2P_IP: "${P2P_IP}"
      LOG_LEVEL: "info"
      P2P_MAX_TX_POOL_SIZE: "1000000000"
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet start --node --archiver --sequencer  ${EXTRA_ARGS}'
    ports:
      - ${TCP_UDP_PORT}:40400/tcp
      - ${TCP_UDP_PORT}:40400/udp
      - ${HTTP_PORT}:8080
    volumes:
      - ${AZTEC_DATA_DIR}:/data
    restart: unless-stopped
EOF
}

# Full installation/reinstallation process with dependency management
install_reinstall() {
  read -p "Warning: This might Install newer version. Do you want to continue? [y/N]: " confirm
  [[ "$confirm" != [yY] ]] && echo "Cancelled." && return

  echo -e "${CYAN}Install/Reinstall started...${RESET}"
  install_dependencies

  cd "$PROJECT_DIR"
  # Clean rebuild to ensure latest versions
  docker compose down
  docker compose build --no-cache
  docker compose pull
  echo -e "${GREEN}✅ Install/Reinstall completed successfully!${RESET}"
}

# Interactive environment configuration editor
edit_env() {
  nano $ENV_FILE
  # Reload the updated environment variables
  if [[ -f "$ENV_FILE" ]]; then
    source $ENV_FILE
  fi
  # Regenerate compose file with new values
  setup_compose_file
  echo -e "${GREEN}✅ .env variables updated successfully!${RESET}"
}

# Clean restart of the Aztec node
start_restart() {
  cd "$PROJECT_DIR"
  docker compose down
  docker compose up -d --force-recreate
  echo -e "${GREEN}✅🔃 Node restarted successfully ${RESET}"
}

# Real-time log streaming
view_logs() {
  echo -e "${CYAN}Streaming logs started (Ctrl+C to exit)...${RESET}"
  cd "$PROJECT_DIR"
  docker compose logs -f
}

# Interactive container status inspection
node_status() {
  list_runing_containers

  echo -n "Enter a container, pick from the above list: "
  read -r container

  if [ -z "$container" ]; then
    echo "No container name provided."
    return 1
  fi

  # Display comprehensive container status information
  echo -e "${CYAN}Docker container status:${RESET}"
  docker inspect -f \
' Name:  {{.Name}}
 Status:  {{.State.Status}}
 Running:  {{.State.Running}}
 Started At:  {{.State.StartedAt}}
 Finished At:  {{.State.FinishedAt}}
 Exit Code:  {{.State.ExitCode}}
 Restarting:  {{.State.Restarting}}
 OOM Killed:  {{.State.OOMKilled}}' $container
}

stop_node() {
  cd "$PROJECT_DIR"
  docker compose down
  echo -e "${RED}🛑 Node stopped.${RESET}"
}

# Complete cleanup including data volumes
clean_up() {
  cd "$PROJECT_DIR"
  docker compose down -v
  rm -rf ./data
  echo -e "${GREEN}🚮 Node cleaned up successfully.${RESET}"
}

# Reload environment variables without restarting
reload_env() {
  if [[ -f "$ENV_FILE" ]]; then
    source $ENV_FILE
  fi
}

list_runing_containers() {
  cd "$PROJECT_DIR"
  echo "List of running containers in this project (empty if none):"
  docker compose ps --format "{{.Name}}"
}

# Interactive shell access to containers with automatic shell detection
enter_container_shell() {
  cd "$PROJECT_DIR"
  list_runing_containers

  echo -n "Enter a container, pick from the above list: "
  read -r container

  if [ -z "$container" ]; then
    echo "No container name provided."
    return 1
  fi

  # Detect available shell (bash preferred, fallback to sh)
  local shell

  if docker exec "$container" test -x /bin/bash; then
    shell="/bin/bash"
  elif docker exec "$container" test -x /bin/sh; then
    shell="/bin/sh"
  else
    echo "No shell found in container $container"
    return 1
  fi

  docker compose exec "$container" "$shell"
}

# System dependencies installation including Docker setup
install_dependencies() {
  echo -e "\n🔧 ${YELLOW}${BOLD}Setting up system dependencies...${RESET}"

  sudo apt update > /dev/null 2>&1
  sudo apt install -y -qq --no-upgrade curl jq git ufw apt-transport-https ca-certificates software-properties-common gnupg lsb-release

  # Docker installation with proper repository setup
  if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."

    # Clean up any existing containerd installations
    sudo apt-get remove -y containerd || true
    sudo apt-get purge -y containerd || true

    # Add Docker's official GPG key and repository
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker with compose plugin
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Configure Docker service and user permissions
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$USER"

    echo "Docker installation complete."
  else
    echo "Docker is already installed."
  fi
}


####################################################################################################
# Aztec-specific utility functions

# Extract sequencer peer ID from container logs
get_sequencer_peer_id_from_logs() {
  echo -e "\n${YELLOW}🆔 Retrieving sequencer PeerId..."

  local peer_id
  peer_id=$(docker logs aztec 2>&1 | grep -i '"peerId"' | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4 | head -n 1)

  if [[ -n "$peer_id" ]]; then
    echo -e "✅ Sequencer PeerId: ${BOLD}$peer_id${RESET}"
  else
    echo -e "❌ ${RED}PeerId not found in logs.${RESET}"
  fi
}

# Fetch latest L2 block information and generate sync proof
show_l2_block_and_sync_proof() {
  echo -e "\n🔍 ${YELLOW}Fetching latest L2 block info..."

  # Query the node for the latest proven block number
  BLOCK=$(curl -s -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' \
    http://localhost:$HTTP_PORT | jq -r ".result.proven.number")

  if [[ -z "$BLOCK" || "$BLOCK" == "null" ]]; then
    echo -e "❌ ${RED}Failed to fetch block number.${RESET}"
    return
  fi

  echo -e "✅ Current L2 Block Number: ${BOLD}$BLOCK${RESET}"
  echo -e "\n🔍 ${CYAN}Computing Proof..."

  # Generate archive sibling path proof for the current block
  PROOF=$(curl -s -X POST -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[\"$BLOCK\",\"$BLOCK\"],\"id\":67}" \
    http://localhost:$HTTP_PORT | jq -r ".result")

  echo -e "🔗 Sync Proof:\n$PROOF ${RESET}"

}

# Detect and display public IP address
fetch_ip() {
  local ip=$(curl -s https://ipinfo.io/ip)
  ip=${ip:-127.0.0.1}

  echo -e "📡 ${YELLOW}Detected server IP: ${GREEN}${BOLD}${ip}${RESET}"
}


####################################################################################################
# Command line argument processing

# Flags and options router 
for arg in "$@"; do
  case $arg in
    --help)
      echo "help"
      exit 0
      ;;
    --healthcheck)
      healthcheck
      exit 0
      ;;
    *)
  esac
done

# Show main menu if no arguments were passed
if [ $# -eq 0 ]; then
  setup_compose_file
  main_menu
  exit 0
fi
