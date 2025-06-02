#!/bin/bash
set -euo pipefail

BOLD=$(tput bold)
RESET=$(tput sgr0)
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"

SCRIPT_DIR_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

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

import_scripts "$SCRIPT_DIR_ABS/../scripts" menu.sh

PROJECT_DIR=$SCRIPT_DIR_ABS
ENV_FILE="$PROJECT_DIR/.env"
AZTEC_DATA_DIR="$PROJECT_DIR/data/aztec"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
USEFUL_PORTS="40400 8080"

# Create directory structure
mkdir -p "$PROJECT_DIR" "$AZTEC_DATA_DIR"

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

if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

# Validate required environment variables
validate_env_vars() {
  local missing_vars=()
  
  [[ -z "${VALIDATOR_PRIVATE_KEY:-}" ]] && missing_vars+=("VALIDATOR_PRIVATE_KEY")
  [[ -z "${P2P_IP:-}" ]] && missing_vars+=("P2P_IP")
  [[ -z "${ETHEREUM_HOSTS:-}" ]] && missing_vars+=("ETHEREUM_HOSTS")
  [[ -z "${L1_CONSENSUS_HOST_URLS:-}" ]] && missing_vars+=("L1_CONSENSUS_HOST_URLS")
  
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Missing required environment variables:${RESET}"
    printf '%s\n' "${missing_vars[@]}"
    echo -e "${YELLOW}Please edit the .env file to set these variables.${RESET}"
    return 1
  fi
  
  return 0
}

# Get container name dynamically
get_aztec_container_name() {
  local container_name
  container_name=$(docker compose ps --format "{{.Name}}" | grep -E "(aztec|node)" | head -n 1)
  
  if [[ -z "$container_name" ]]; then
    echo "aztec"  # fallback to default name
  else
    echo "$container_name"
  fi
}

# Register additional menu actions
register_menu_item "[10] Fetch L2 Block + Sync Proof" show_l2_block_and_sync_proof
register_menu_item "[11] Retrieve Sequencer PeerId" get_sequencer_peer_id_from_logs
register_menu_item "[12] Display Public IP Address" fetch_ip


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

install_reinstall() {
  read -p "Warning: This might Install newer version. Do you want to continue? [y/N]: " confirm
  [[ "$confirm" != [yY] ]] && echo "Cancelled." && return

  echo -e "${CYAN}Install/Reinstall started...${RESET}"
  install_dependencies

  cd "$PROJECT_DIR"
  docker compose down
  docker compose build --no-cache
  docker compose pull
  echo -e "${GREEN}✅ Install/Reinstall completed successfully!${RESET}"
}

edit_env() {
  nano "$ENV_FILE"
  if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
  fi
  setup_compose_file
  echo -e "${GREEN}✅ .env variables updated successfully!${RESET}"
}

start_restart() {
  # Validate environment variables before starting
  if ! validate_env_vars; then
    echo -e "${RED}❌ Cannot start node due to missing environment variables.${RESET}"
    return 1
  fi
  
  cd "$PROJECT_DIR"
  docker compose down
  docker compose up -d --force-recreate
  echo -e "${GREEN}✅🔃 Node restarted successfully ${RESET}"
}

view_logs() {
  echo -e "${CYAN}Streaming logs started (Ctrl+C to exit)...${RESET}"
  cd "$PROJECT_DIR"
  docker compose logs -f
}

node_status() {
  list_running_containers

  echo -n "Enter a container, pick from the above list: "
  read -r container

  if [ -z "$container" ]; then
    echo "No container name provided."
    return 1
  fi

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

clean_up() {
  cd "$PROJECT_DIR"
  docker compose down -v
  rm -rf ./data
  echo -e "${GREEN}🚮 Node cleaned up successfully.${RESET}"
}

reload_env() {
  if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
  fi
}

list_running_containers() {
  cd "$PROJECT_DIR"
  echo "List of running containers in this project (empty if none):"
  docker compose ps --format "{{.Name}}"
}

enter_container_shell() {
  cd "$PROJECT_DIR"
  list_running_containers

  echo -n "Enter a container, pick from the above list: "
  read -r container

  if [ -z "$container" ]; then
    echo "No container name provided."
    return 1
  fi

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

install_dependencies() {
  echo -e "\n🔧 ${YELLOW}${BOLD}Setting up system dependencies...${RESET}"

  sudo apt update > /dev/null 2>&1
  sudo apt install -y -qq --no-upgrade curl jq git ufw apt-transport-https ca-certificates software-properties-common gnupg lsb-release

  if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."

    sudo apt-get remove -y containerd || true
    sudo apt-get purge -y containerd || true

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$USER"

    echo "Docker installation complete."
  else
    echo "Docker is already installed."
  fi
}

# Health check function
healthcheck() {
  echo -e "${CYAN}🔍 Performing health check...${RESET}"
  
  # Check if Docker is running
  if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${RESET}"
    return 1
  fi
  
  # Check if compose file exists
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo -e "${RED}❌ Docker compose file not found${RESET}"
    return 1
  fi
  
  # Check if container is running
  local container_name
  container_name=$(get_aztec_container_name)
  
  if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
    echo -e "${GREEN}✅ Container '${container_name}' is running${RESET}"
    
    # Check if HTTP port is responding
    if curl -s -f "http://localhost:${HTTP_PORT:-8080}" >/dev/null 2>&1; then
      echo -e "${GREEN}✅ HTTP endpoint is responding${RESET}"
    else
      echo -e "${YELLOW}⚠️  HTTP endpoint not responding${RESET}"
    fi
  else
    echo -e "${RED}❌ Container '${container_name}' is not running${RESET}"
  fi
  
  echo -e "${GREEN}✅ Health check completed${RESET}"
}

####################################################################################################


get_sequencer_peer_id_from_logs() {
  echo -e "\n${YELLOW}🆔 Retrieving sequencer PeerId..."

  local container_name
  container_name=$(get_aztec_container_name)
  
  local peer_id
  peer_id=$(docker logs "$container_name" 2>&1 | grep -i '"peerId"' | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4 | head -n 1)

  if [[ -n "$peer_id" ]]; then
    echo -e "✅ Sequencer PeerId: ${BOLD}$peer_id${RESET}"
  else
    echo -e "❌ ${RED}PeerId not found in logs.${RESET}"
  fi
}

show_l2_block_and_sync_proof() {
  echo -e "\n🔍 ${YELLOW}Fetching latest L2 block info..."

  BLOCK=$(curl -s -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' \
    http://localhost:$HTTP_PORT | jq -r ".result.proven.number")

  if [[ -z "$BLOCK" || "$BLOCK" == "null" ]]; then
    echo -e "❌ ${RED}Failed to fetch block number.${RESET}"
    return
  fi

  echo -e "✅ Current L2 Block Number: ${BOLD}$BLOCK${RESET}"
  echo -e "\n🔍 ${CYAN}Computing Proof..."

  PROOF=$(curl -s -X POST -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[\"$BLOCK\",\"$BLOCK\"],\"id\":67}" \
    http://localhost:$HTTP_PORT | jq -r ".result")

  echo -e "🔗 Sync Proof:\n$PROOF ${RESET}"

}

fetch_ip() {
  local ip=$(curl -s https://ipinfo.io/ip)
  ip=${ip:-127.0.0.1}

  echo -e "📡 ${YELLOW}Detected server IP: ${GREEN}${BOLD}${ip}${RESET}"
}


####################################################################################################

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
