#!/bin/bash
set -euo pipefail

BOLD=$(tput bold)
RESET=$(tput sgr0)
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"

# Additional colors from menu.sh
readonly COLOR_RESET=$(tput sgr0)
readonly COLOR_BOLD=$(tput bold)
readonly COLOR_RED=$(tput setaf 1)
readonly COLOR_GREEN=$(tput setaf 2)
readonly COLOR_YELLOW=$(tput setaf 3)
readonly COLOR_CYAN=$(tput setaf 6)

# UI helpers from menu.sh
info()    { echo -e "${COLOR_CYAN}${1}${COLOR_RESET}"; }
success() { echo -e "${COLOR_GREEN}${1}${COLOR_RESET}"; }
warning() { echo -e "${COLOR_YELLOW}${1}${COLOR_RESET}"; }
error()   { echo -e "${COLOR_RED}${1}${COLOR_RESET}" >&2; }

pause() {
  echo
  read -rp "${COLOR_BOLD}${COLOR_GREEN} 🔙🔙 Back to main menu? << ${COLOR_RESET}"
}

# External hooks for menu system
EXTRA_MENU_ITEMS=()
EXTRA_MENU_FUNCTIONS=()

register_menu_item() {
  EXTRA_MENU_ITEMS+=("$1")         # e.g., "42) My Special Task"
  EXTRA_MENU_FUNCTIONS+=("$2")     # e.g., "my_special_task"
}

invoke_extra_menu_function() {
  local choice="$1"
  for i in "${!EXTRA_MENU_ITEMS[@]}"; do
    local item="${EXTRA_MENU_ITEMS[i]}"
    local num="${item#[}"; num="${num%%]*}" # trim [ and ]
    if [[ "$choice" == "$num" ]]; then
      "${EXTRA_MENU_FUNCTIONS[i]}"
      return 0
    fi
  done
  return 1
}

print_extra_menu_items() {
  for item in "${EXTRA_MENU_ITEMS[@]}"; do
    echo "  $item"
  done
  echo "${COLOR_RESET}"
}

SCRIPT_DIR_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

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
  warning "Factory reset selected! This will delete all data."
  read -rp "Are you sure? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    cd "$PROJECT_DIR"
    docker compose down -v
    rm -rf ./data
    success "Factory reset completed."
  else
    info "Factory reset cancelled."
  fi
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

show_help() {
  echo -e "${COLOR_BOLD}${COLOR_CYAN}AZTEC NODE SETUP - HELP${COLOR_RESET}"
  echo
  echo -e "${COLOR_BOLD}${COLOR_CYAN}Available Options:${COLOR_RESET}${COLOR_YELLOW}"
  echo "  [1] Install/Reinstall     - Install or reinstall the node."
  echo "  [2] Edit .env file        - Open the .env configuration file."
  echo "  [3] Start/Restart         - Start or restart the node process."
  echo "  [4] View Logs             - Show real-time node logs."
  echo "  [5] Status                - Check node status and health."
  echo "  [6] Stop                  - Stop the running node."
  echo "  [7] Shell                 - Open an interactive shell in the container."
  echo "  [8] Help                  - Show this help information."
  echo "  [RESET] Factory Reset     - Erase all data and reset to defaults."
  echo "  [0] Exit                  - Exit the menu."
  echo
  echo -e "${COLOR_BOLD}${COLOR_CYAN}Extra Items:${COLOR_RESET}${COLOR_YELLOW}"
  echo "  [10] Fetch L2 Block + Sync Proof  - Get latest L2 block and sync proof."
  echo "  [11] Retrieve Sequencer PeerId     - Get sequencer peer ID from logs."
  echo "  [12] Display Public IP Address     - Show server's public IP address."
  echo
  echo -e "${COLOR_BOLD}${COLOR_CYAN}Tips:${COLOR_RESET}${COLOR_YELLOW}"
  echo "  - Use arrow keys or numbers to select options."
  echo "  - Press Ctrl+C to quit logs view."
  echo ${COLOR_RESET}
}

# Main menu function (integrated from menu.sh)
main_menu() {
  while true; do
    clear
    echo -e "${COLOR_CYAN}${COLOR_BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    👻 DLORD • AZTEC SETUP                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"

    echo -e "${COLOR_CYAN}Choose an option:"
    echo "  [1] Install/Reinstall"
    echo "  [2] Edit .env file"
    echo "  [3] Start/Restart"
    echo "  [4] View Logs"
    echo "  [5] Status"
    echo "  [6] Stop"
    echo "  [7] Shell"
    echo "  [8] Help"
    echo "  [RESET] Factory Reset"
    echo "  [0] Exit ${COLOR_RESET}"

    echo -e "${COLOR_YELLOW}${COLOR_BOLD}"; 
    print_extra_menu_items
    echo "${COLOR_RESET}"
    
    read -p "👉 Enter choice: " CHOICE

    case "$CHOICE" in
      1) install_reinstall ;;
      2) edit_env ;;
      3) start_restart ;;
      4) view_logs ;;
      5) node_status ;;
      6) stop_node ;;
      7) enter_container_shell ;;
      8) show_help ;;
      RESET) clean_up ;;
      0)
        echo -e "${COLOR_YELLOW}Goodbye.${COLOR_RESET}"
        exit 0
        ;;
      *)
        if ! invoke_extra_menu_function "$CHOICE"; then
          error "Invalid option."
        fi
        ;;
    esac

    pause
  done
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
