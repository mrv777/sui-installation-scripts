#!/bin/bash

#
# This script updates a sui node on an ubuntu/debian server
# installed with https://github.com/mrv777/sui-installation-scripts
#

###################################################################################################
# DEFINES
###################################################################################################

SUI_NODE_FOLDER="sui"
SUI_NODE_SERVICE="sui-node"
SUI_NODE_NETWORK="devnet"
HOME_DIR="${HOME}"

###################################################################################################
# HELPER FUNCTIONS
###################################################################################################

## Make sure we are in the correct directory
function ChangeDirectory() {
  cd ~
  eval "cd $HOME_DIR"
}

function exists() {
  command -v "$1" >/dev/null 2>&1
}

###################################################################################################
# MAIN
###################################################################################################

echo "" && echo '[INFO] Checking script version'
read -r current_version <VERSION
remote_version=$(wget -qO- https://raw.githubusercontent.com/mrv777/sui-installation-scripts/main/VERSION)
echo "[INFO] Local version: $current_version"
echo "[INFO] Remote version: $remote_version"
if [ $remote_version -gt $current_version ]; then
  echo "" && echo "[ERROR] There is a new version of the script available. Please update."
  echo "Exiting..." && echo ""
  exit 1
fi
echo "" && echo '[INFO] No script updates. Continuing...'

echo "" && echo '[INFO] Checking node version'
remote_node_version=$(curl -sL https://api.github.com/repos/MystenLabs/sui/tags | jq -r ".[1].name" | cut -d "-" -f2)
node_version=$(grep 'version =' /${HOME_DIR}/${SUI_NODE_FOLDER}/crates/sui/Cargo.toml -m 1 | cut -d'"' -f 2)
echo "[INFO] Local node version: $node_version"
echo "[INFO] Remote node version: $remote_node_version"
if [ $node_version == $remote_node_version ]; then
  echo "" && echo "[ERROR] There is no new version of the node software available."
  echo "Exiting..." && echo ""
  exit 2
fi

[ "${RUN_UPDATE:-}" ] || read -r -p "Update available, would you like to update SUI? (Default yes): " RUN_UPDATE
RUN_UPDATE=${RUN_UPDATE:-yes}
if [ "$RUN_UPDATE" == "no" ]; then
  echo "Exiting..." && echo ""
  exit 1
fi

echo "" && echo '[INFO] Stopping service'
sudo systemctl stop ${SUI_NODE_SERVICE}.service
sleep 1

echo "" && echo '[INFO] Removing old files'
sudo rm -rf $HOME_DIR/sui
source $HOME_DIR/.cargo/env
sleep 1

echo "" && echo "[INFO] Working in the directory: $HOME_DIR"
ChangeDirectory
sleep 1

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
sleep 1

echo "" && echo '[INFO] Building sui node (this will take awhile)'
cargo build --release -p sui-node &>sui_update_cargo_build_log.txt
sudo sed -i.bak 's/127.0.0.1/0.0.0.0/' fullnode.yaml
sleep 1

echo "" && echo '[INFO] Restarting service'
sudo systemctl restart ${SUI_NODE_SERVICE}.service
sleep 1

echo ""
echo "==================================================="
echo "" && echo '[INFO] Check Sui status'
if [[ $(service ${SUI_NODE_SERVICE} status | grep active) =~ "running" ]]; then
  echo -e "Your Sui Node \e[32mis updated\e[39m!"
  echo -e "You can check node status by the command \e[7mservice ${SUI_NODE_SERVICE} status\e[0m"
  echo -e "You can check node logs with the command \e[7msudo journalctl -u ${SUI_NODE_SERVICE} -f -o cat\e[0m"
  echo -e "You can also check the node status online at \e[7mhttps://node.sui.zvalid.com/\e[0m"
else
  echo -e "Your Sui Node \e[31mwas not updated correctly\e[39m"
  echo -e "You can check the logs with the command \e[7msudo journalctl -u ${SUI_NODE_SERVICE} -f -o cat\e[0m"
fi
