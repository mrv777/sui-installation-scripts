# Sui Installation Scripts

[Sui](http://sui.io/) node installation scripts for Debian based servers.

## Features

- Download Sui software
- Download and install dependencies
- Setup service to automatically start Sui after a reboot and run it in the background
- Setup ufw firewall
- (Soon) Option for daily automatic update check/install

## Getting Started

If you only have a root user or are unsure, start here

- `wget https://raw.githubusercontent.com/mrv777/sui-installation-scripts/master/create-sudo-user.sh`
- `bash ./create-sudo-user.sh -u {username} -p {password}`
  Remove the {username} with your username and the same for password

Logout and log back in as new user.
Now that we have a regular user we can do the 2 commands to get and set everything up:

- `wget https://raw.githubusercontent.com/mrv777/sui-installation-scripts/master/install-sui.sh`
- `screen -S sui -m bash ./install-sui.sh`

## Files

### install-sui.sh

This is the _main_ script. It installs, creates and configures all necessary parts to run an Sui node.

To install a sui node, copy the script to the Debian server and run `bash ./install-sui.sh`. It is designed to run with a sudo user.

If you don't have a sudo user on the server yet (for example if just created a new Ubuntu Droplet from Digital Ocean), you can use the _create-sudo-user.sh_ script to automatically create one.

### create-sudo-user.sh

This script lets you create a sudo user with ease. Call it with `./create-sudo-user.sh -h` for parameter description.
