#!/bin/bash

#
# This script installs an sui node on an ubuntu/debian server.
# It is based on the official installation guide
# (https://docs.sui.io/build/fullnode)
#

###################################################################################################
# DEFAULTS
###################################################################################################

DEFAULT_INSTALL_LOCATION=$(pwd)

###################################################################################################
# CONFIGURATION
###################################################################################################

REBOOT=true

###################################################################################################
# DEFINES
###################################################################################################

SUI_NODE_FOLDER="sui"

SUI_NODE_SERVICE="sui-node"

LOCAL_USER=$(whoami)
HOME_DIR="${HOME}"

PROFILE_LANGUAGE_VARIABLE="
export LANGUAGE=\"en_US.UTF-8\"
export LANG=\"en_US.UTF-8 \"
export LC_ALL=\"en_US.UTF-8\"
export LC_CTYPE=\"en_US.UTF-8\"
"

SUI_NODE_SERVICE_FILE_CONTENT="
[Unit]
Description=Sui-Node
After=syslog.target
After=network.target

[Service]
RestartSec=2s
Type=simple
WorkingDirectory=${HOME_DIR}/${SUI_NODE_FOLDER}/target/release/
ExecStart=${HOME_DIR}/${SUI_NODE_FOLDER}/target/release/sui-node --config-path ${HOME_DIR}/${SUI_NODE_FOLDER}/fullnode.yaml
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
"

UNATTENDED_UPGRADE_PERIODIC_CONFIG_FILE_CONTENT="
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Download-Upgradeable-Packages \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
APT::Periodic::AutocleanInterval \"1\";
"

###################################################################################################
# HELPER FUNCTIONS
###################################################################################################

## Make sure we are in the correct directory
function ChangeDirectory() {
  cd ~
  eval "cd $DEFAULT_INSTALL_LOCATION"
}

function exists() {
  command -v "$1" >/dev/null 2>&1
}

###################################################################################################
# MAIN
###################################################################################################
echo ""
date +"%Y-%m-%d %H:%M:%S || [INFO] Sui install script started"
# Verification Checks
if [ $UID -eq 0 ]; then
  echo "[ERROR] $0 should not be run as root."
  echo "You can run 'bash ./create-sudo-user.sh' to create a new user"
  echo "Exiting..."
  exit 1
fi
if [ -z "$(grep -Ei 'debian|ubuntu|mint' /etc/*release)" ]; then
  echo "Error: only debian based OS is supported."
  exit 2
fi

echo "" && echo "[INFO] Working in the directory: $DEFAULT_INSTALL_LOCATION"
ChangeDirectory

# Check if curl exists
if exists curl; then
  echo ''
else
  sudo apt update && sudo apt install curl -y <"/dev/null"
fi
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
  . $HOME/.bash_profile
fi

echo -e '[INFO] Install software' && sleep 1
sudo apt-get update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC sudo apt-get install -y --no-install-recommends tzdata git ca-certificates curl build-essential libssl-dev pkg-config libclang-dev cmake jq
echo -e '[INFO] Install Rust' && sleep 1
sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

# sudo rm -rf /var/sui/db /var/sui/genesis.blob $HOME/sui
# sudo mkdir -p /var/sui/db
# cd $HOME

echo -e '[INFO] Check out GIT repo' && sleep 1
# Set up your fork of the Sui repository
git clone https://github.com/MystenLabs/sui.git
cd sui
# Set up the Sui repository as a git remote
git remote add upstream https://github.com/MystenLabs/sui
# Sync your fork
git fetch upstream
# Check out the devnet branch
git checkout --track upstream/devnet
# Make a copy of the fullnode configuration template:
cp crates/sui-config/data/fullnode-template.yaml fullnode.yaml
# Download the latest genesis state
curl -fLJO https://github.com/MystenLabs/sui-genesis/raw/main/devnet/genesis.blob

sudo sed -i.bak "s/genesis-file-location:.*/genesis-file-location: \"\/${HOME_DIR}\/${SUI_NODE_FOLDER}\/genesis.blob\"/" /${HOME_DIR}/${SUI_NODE_FOLDER}/fullnode.yaml
# sudo wget -O /var/sui/genesis.blob https://github.com/MystenLabs/sui-genesis/raw/main/devnet/genesis.blob

# sudo sed -i.bak "s/db-path:.*/db-path: \"\/var\/sui\/db\"/ ; s/genesis-file-location:.*/genesis-file-location: \"\/var\/sui\/genesis.blob\"/" /var/sui/fullnode.yaml

echo -e '[INFO] Build sui node' && sleep 1
cargo build --release -p sui-node
sudo sed -i.bak 's/127.0.0.1/0.0.0.0/' fullnode.yaml

echo "" && echo "[INFO] creating sui node service and logs ..."
sudo mkdir -p /etc/systemd/system
echo "${SUI_NODE_SERVICE_FILE_CONTENT}" | sudo tee /etc/systemd/system/${SUI_NODE_SERVICE}.service >/dev/null
sudo tee /etc/systemd/journald.conf <<EOF >/dev/null
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload

echo "" && echo "[INFO] enabling sui node service ..."
sudo systemctl enable ${SUI_NODE_SERVICE}.service
sudo systemctl restart sui-node

echo "==================================================="
echo -e '[INFO] Check Sui status' && sleep 1
if [[ $(service sui-node status | grep active) =~ "running" ]]; then
  echo -e "Your Sui Node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice sui-node status\e[0m"
  echo -e "You can check node logs by the command \e[7msudo journalctl -u sui-node -f -o cat\e[0m"
  echo -e "You can also check the node status online at \e[7mhttps://node.sui.zvalid.com/\e[0m"
else
  echo -e "Your Sui Node \e[31mwas not installed correctly\e[39m, please reinstall."
fi

[ "${SETUP_FIREWALL:-}" ] || read -r -p "It is recommended that you setup and enable ufw, would you like to do that now? (Default yes): " SETUP_FIREWALL
SETUP_FIREWALL=${SETUP_FIREWALL:-yes}
if [ "$SETUP_FIREWALL" == "yes" ]; then
  echo -e '[INFO] Install ufw' && sleep 1
  sudo apt-get install ufw

  echo -e '[INFO] Allow default ports for ufw' && sleep 1
  sudo ufw allow 9184
  sudo ufw allow 9000
  sudo ufw allow 8080
  sudo ufw allow 22

  echo -e '[INFO] Enable ufw' && sleep 1
  sudo ufw enable

  echo -e '[INFO] Check ufw status' && sleep 1
  sudo ufw status
fi
