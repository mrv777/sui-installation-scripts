#!/bin/bash

#
# This script installs a sui node on an ubuntu/debian server.
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
SUI_NODE_NETWORK="devnet"

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
  echo ""
  echo "[ERROR] $0 should not be run as root."
  echo -e "You can get the new user script with \e[7mwget https://raw.githubusercontent.com/mrv777/sui-installation-scripts/master/create-sudo-user.sh\e[0m"
  echo -e "Then you can run \e[7mbash ./create-sudo-user.sh\e[0m to create a new user"
  echo "Exiting..."
  echo ""
  exit 1
fi
if [ -z "$(grep -Ei 'debian|ubuntu|mint' /etc/*release)" ]; then
  echo ""
  echo "Error: only debian based OS is supported."
  echo "Exiting..."
  echo ""
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

echo "" && echo '[INFO] Install dependencies' && sleep 1
sudo apt-get update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC sudo apt-get install -y --no-install-recommends tzdata git ca-certificates curl build-essential libssl-dev pkg-config libclang-dev cmake jq
echo "" && echo '[INFO] Install Rust' && sleep 1
sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

# sudo rm -rf /var/sui/db /var/sui/genesis.blob $HOME/sui
# sudo mkdir -p /var/sui/db
# cd $HOME

echo "" && echo '[INFO] Check out GIT repo'
# Set up your fork of the Sui repository
git clone https://github.com/MystenLabs/sui.git
cd sui
# Set up the Sui repository as a git remote
git remote add upstream https://github.com/MystenLabs/sui
# Sync your fork
git fetch upstream
# Check out the devnet branch
git checkout --track upstream/${SUI_NODE_NETWORK}
# Make a copy of the fullnode configuration template:
cp crates/sui-config/data/fullnode-template.yaml fullnode.yaml
# Download the latest genesis state
curl -fLJO https://github.com/MystenLabs/sui-genesis/raw/main/${SUI_NODE_NETWORK}/genesis.blob
# Set path of genesis file in config file
sudo sed -i.bak "s|genesis-file-location:.*|genesis-file-location: \"${HOME_DIR}\/${SUI_NODE_FOLDER}\/genesis.blob\"|" /${HOME_DIR}/${SUI_NODE_FOLDER}/fullnode.yaml
# sudo wget -O /var/sui/genesis.blob https://github.com/MystenLabs/sui-genesis/raw/main/devnet/genesis.blob
sleep 1
# sudo sed -i.bak "s/db-path:.*/db-path: \"\/var\/sui\/db\"/ ; s/genesis-file-location:.*/genesis-file-location: \"\/var\/sui\/genesis.blob\"/" /var/sui/fullnode.yaml

echo "" && echo '[INFO] Building sui node (this will take awhile)'
cargo build --release -p sui-node &>sui_cargo_build_log.txt
sudo sed -i.bak 's/127.0.0.1/0.0.0.0/' fullnode.yaml
sleep 1

echo "" && echo "[INFO] creating sui node service and logs ..."
sudo mkdir -p /etc/systemd/system
echo "${SUI_NODE_SERVICE_FILE_CONTENT}" | sudo tee /etc/systemd/system/${SUI_NODE_SERVICE}.service >/dev/null
sudo tee /etc/systemd/journald.conf <<EOF >/dev/null
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sleep 1

echo "" && echo "[INFO] enabling sui node service ..."
sudo systemctl enable ${SUI_NODE_SERVICE}.service
sudo systemctl restart sui-node
sleep 1

echo ""
echo "==================================================="
echo '[INFO] Check Sui status' && sleep 1
if [[ $(service sui-node status | grep active) =~ "running" ]]; then
  echo -e "Your Sui Node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice sui-node status\e[0m"
  echo -e "You can check node logs with the command \e[7msudo journalctl -u sui-node -f -o cat\e[0m"
  echo -e "You can also check the node status online at \e[7mhttps://node.sui.zvalid.com/\e[0m"
else
  echo -e "Your Sui Node \e[31mwas not installed correctly\e[39m"
  echo -e "You can check the logs with the command \e[7msudo journalctl -u sui-node -f -o cat\e[0m"
fi

[ "${SETUP_FIREWALL:-}" ] || read -r -p "It is recommended that you setup and enable ufw, would you like to do that now? (Default yes): " SETUP_FIREWALL
SETUP_FIREWALL=${SETUP_FIREWALL:-yes}
if [ "$SETUP_FIREWALL" == "yes" ]; then
  echo "" && echo '[INFO] Install ufw' && sleep 1
  sudo apt-get install ufw

  [ "${SSH_PORT:-}" ] || read -r -p "What port should be left open for SSH? (Default 22): " SSH_PORT
  SSH_PORT=${SSH_PORT:-22}

  echo "" && echo '[INFO] Allow default ports for ufw' && sleep 1
  sudo ufw allow 9184
  sudo ufw allow 9000
  sudo ufw allow 8080
  sudo ufw allow $SSH_PORT

  echo "" && echo '[INFO] Enable ufw' && sleep 1
  sudo ufw enable

  echo "" && echo '[INFO] Check ufw status' && sleep 1
  sudo ufw status
fi

[ "${SETUP_UPDATE:-}" ] || read -r -p "Would you like to add a script to update SUI? (Default yes): " SETUP_UPDATE
SETUP_UPDATE=${SETUP_UPDATE:-yes}
if [ "$SETUP_UPDATE" == "yes" ]; then

  echo "" && echo "[INFO] Working in the directory: $DEFAULT_INSTALL_LOCATION"
  ChangeDirectory
  echo '[INFO] Downloading script' && sleep 1
  curl -fLJO https://raw.githubusercontent.com/mrv777/sui-installation-scripts/main/VERSION
  curl -fLJO https://raw.githubusercontent.com/mrv777/sui-installation-scripts/main/update-sui.sh
  echo -e "You can update your node with the command \e[7mbash ./update-sui.sh\e[0m"
fi
