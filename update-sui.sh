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
HOME_DIR="${HOME}"

###################################################################################################
# MAIN
###################################################################################################

echo "" && echo '[INFO] Stopping service' && sleep 1
sudo systemctl stop ${SUI_NODE_SERVICE}.service

echo "" && echo '[INFO] Removing old files' && sleep 1
rm -rf /var/sui/db/* /var/sui/genesis.blob $HOME/sui
source $HOME/.cargo/env

echo "" && echo '[INFO] Check out GIT repo' && sleep 1
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

echo "" && echo '[INFO] Build sui node' && sleep 1
cargo build --release -p sui-node
sudo sed -i.bak 's/127.0.0.1/0.0.0.0/' fullnode.yaml

echo "" && echo '[INFO] Restarting service' && sleep 1
sudo systemctl restart ${SUI_NODE_SERVICE}.service

echo ""
echo "==================================================="
echo "" && echo '[INFO] Check Sui status' && sleep 1
if [[ $(service sui-node status | grep active) =~ "running" ]]; then
  echo -e "Your Sui Node \e[32mis updated\e[39m!"
  echo -e "You can check node status by the command \e[7mservice sui-node status\e[0m"
  echo -e "You can check node logs with the command \e[7msudo journalctl -u sui-node -f -o cat\e[0m"
  echo -e "You can also check the node status online at \e[7mhttps://node.sui.zvalid.com/\e[0m"
else
  echo -e "Your Sui Node \e[31mwas not updated correctly\e[39m"
  echo -e "You can check the logs with the command \e[7msudo journalctl -u sui-node -f -o cat\e[0m"
fi
