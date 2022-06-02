#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '    _                 _                      '
echo -e '   / \   ___ __ _  __| | ___ _ __ ___  _   _ '
echo -e '  / _ \ / __/ _  |/ _  |/ _ \  _   _ \| | | |'
echo -e ' / ___ \ (_| (_| | (_| |  __/ | | | | | |_| |'
echo -e '/_/   \_\___\__ _|\__ _|\___|_| |_| |_|\__  |'
echo -e '                                       |___/ '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Wallet"
"Faucet"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"


# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
echo "export WALLET=wallet" >> $HOME/.bash_profile
echo "export CHAIN_ID=harpoon-3" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y
sudo apt update && sudo apt dist-upgrade -y
sudo apt install build-essential git unzip curl wget -y


# install go
source $HOME/.bash_profile
    if go version > /dev/null 2>&1
    then
        echo -e '\n\e[40m\e[92mSkipped Go installation\e[0m'
    else
        echo -e '\n\e[40m\e[92mStarting Go installation...\e[0m'
        ver="1.18.1" && \
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
rm "go$ver.linux-amd64.tar.gz" && \
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile && \
source $HOME/.bash_profile && \
go version
    fi

# download binary
git clone https://github.com/Team-Kujira/core $HOME/kujira-core
cd $HOME/kujira-core
make install
kujirad version

# config
kujirad config chain-id harpoon-3
kujirad config keyring-backend file

# init
kujirad init $NODENAME --chain-id $CHAIN_ID

# download genesis and addrbook
wget https://raw.githubusercontent.com/Team-Kujira/networks/master/testnet/harpoon-3.json -O $HOME/.kujira/config/genesis.json
wget https://raw.githubusercontent.com/Team-Kujira/networks/master/testnet/addrbook.json -O $HOME/.kujira/config/addrbook.json

# set minimum gas price
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"1ukuji\"/" $HOME/.kujira/config/app.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.kujira/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="809"
pruning_keep_every="0"
pruning_interval="43"

sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.kujira/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.kujira/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.kujira/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.kujira/config/app.toml

# reset
kujirad tendermint unsafe-reset-all

# create service
sudo tee /etc/systemd/system/kujirad.service > /dev/null <<EOF
[Unit]
Description=Kujira Daemon
After=network.target
[Service]
Type=simple
User=root
ExecStart=/root/go/bin/kujirad start --log_level error 
Restart=on-failure
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# start service
sudo systemctl daemon-reload
sudo systemctl enable kujirad
sudo systemctl restart kujirad

break
;;

"Create Wallet")
kujirad keys add $WALLET
echo "============================================================"
echo "Save address and mnemonic"
echo "============================================================"
WALLET_ADDRESS=$(kujirad keys show $WALLET -a)
VALOPER_ADDRESS=$(kujirad keys show $WALLET --bech val -a)
echo 'export WALLET_ADDRESS='${WALLET_ADDRESS} >> $HOME/.bash_profile
echo 'export VALOPER_ADDRESS='${VALOPER_ADDRESS} >> $HOME/.bash_profile
source $HOME/.bash_profile

break
;;

"Faucet")
curl -X POST https://faucet.kujira.app/$WALLET

break
;;

"Create Validator")
  kujirad tx staking create-validator 
  --moniker $NODENAME \
  --amount=1000000ukuji \
  --gas-prices=1ukuji \
  --pubkey $(kujirad tendermint show-validator) \
  --from $WALLET \
  --yes \
  --node=tcp://localhost:26657 \
  --chain-id $CHAIN_ID \
  --commission-max-change-rate=0.01 \
  --commission-max-rate=0.20 \
  --commission-rate=0.10 \
  --min-self-delegation=1
  
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
