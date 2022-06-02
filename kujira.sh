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
rm -rf $HOME/kujira-core
git clone https://github.com/Team-Kujira/core $HOME/kujira-core
cd $HOME/kujira-core
make install
sleep 1
ln -s $HOME/go/bin/kujirad /usr/local/bin/kujirad
# init
kujirad init $NODENAME --chain-id $CHAIN_ID

# config
kujirad config chain-id harpoon-3
kujirad config keyring-backend file

# download genesis and addrbook
wget https://raw.githubusercontent.com/Team-Kujira/networks/master/testnet/harpoon-3.json -O $HOME/.kujira/config/genesis.json
wget https://raw.githubusercontent.com/Team-Kujira/networks/master/testnet/addrbook.json -O $HOME/.kujira/config/addrbook.json

# set minimum gas price
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"1ukuji\"/" $HOME/.kujira/config/app.toml

#peers and seeds
SEEDS="8e1590558d8fede2f8c9405b7ef550ff455ce842@51.79.30.9:26656,bfffaf3b2c38292bd0aa2a3efe59f210f49b5793@51.91.208.71:26656,106c6974096ca8224f20a85396155979dbd2fb09@198.244.141.176:26656"
PEERS="111ba4e5ae97d5f294294ea6ca03c17506465ec5@208.68.39.221:26656,b16142de5e7d89ee87f36d3bbdd2c2356ca2509a@75.119.155.248:26656,ad7b2ecb931a926d60d1e034d0e37a83d0e265f1@109.107.181.127:26656,1b827c298f013900476c2eab25ce5ff75a6f8700@178.63.62.212:26656,111ba4e5ae97d5f294294ea6ca03c17506465ec5@208.68.39.221:26656,f114c02efc5aa7ee3ee6733d806a1fae2fbfb66b@5.189.178.222:46656,8980faac5295875a5ecd987a99392b9da56c9848@85.10.216.151:26656,3c3170f0bcbdcc1bef12ed7b92e8e03d634adf4e@65.108.103.236:27656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.kujira/config/config.toml

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
echo "[Unit]
Description=Kujirad Node
After=network.target
[Service]
User=$USER
Type=simple
ExecStart=$(which kujirad) start
Restart=on-failure
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target" > $HOME/kujirad.service
sudo mv $HOME/kujirad.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF

# start service
sudo systemctl restart systemd-journald
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
  kujirad tx staking create-validator \
  --moniker $NODENAME \
  --amount=1000000ukuji \
  --gas-prices=20000ukuji \
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
