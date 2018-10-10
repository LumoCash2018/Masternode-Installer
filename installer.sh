#!/bin/bash


YELLOW='\u001b[33m'
RED='\u001b[31m'
GREEN='\u001b[32m'
RESET='\033[0m'


printf "${YELLOW}==================================================================\n"
printf "                  LumoCash Masternode Installer\n"
printf "==================================================================${RESET}\n"

printf "${GREEN}Please choose a name for you Masternode:${RESET}\n"
read MNNAME
printf "${GREEN}Please enter your Masternode Private key:${RESET}\n"
read MNKEY
until [ ${#MNKEY} -ge 51 ] && [ ! ${#MNKEY} -ge 52 ]; do
             printf "${RED}Masternode key incorrect length! Please ensure it is correct and try again:${RESET}\n"
             read MNKEY
done
printf "${GREEN}Please enter your Masternode TXID:${RESET}\n"
read MNTX
until [ ${#MNTX} -ge 64 ] && [ ! ${#MNTX} -ge 65 ]; do
             printf "${RED}Masternode TXID incorrect length! Please ensure it is correct and try again:${RESET}\n"
             read MNTX
done
printf "${GREEN}Please enter your Masternode TXID index:${RESET}\n"
read MNTXI
until [[ "$MNTXI" =~ ^[0-9]+$ ]]; do
             printf "${RED}Masternode TXID index should be integer! Please ensure it is correct and try again:${RESET}\n"
             read MNTXI
done

printf "${GREEN}Installing packages and updates${RESET}\n"

sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get update -y
sudo apt-get install git -y
sudo apt-get install nano -y
sudo apt-get install pwgen -y
sudo apt-get install dnsutils -y
sudo apt-get install zip unzip -y
sudo apt-get install libzmq3-dev -y
sudo apt-get install libboost-all-dev -y
sudo apt-get install libminiupnpc-dev -y
sudo apt-get install build-essential  libssl-dev libminiupnpc-dev libevent-dev -y
sudo apt-get install libdb4.8-dev libdb4.8++-dev -y
sudo apt-get install python-virtualenv -y

RELEASE="v1.0.1.1"
PORT="6562"
PASS=$(pwgen -1 20 -n)
VPSIP=$(dig +short myip.opendns.com @resolver1.opendns.com)

printf "${GREEN}Setting up locales${RESET}\n"

export LANG="en_US.utf8"
export LANGUAGE="en_US.utf8"
export LC_ALL="en_US.utf8"

printf "${GREEN}Checking for old LumoCash files${RESET}\n"

if pgrep -x "lumocashd" > /dev/null
then
    printf "${RED}Killing old LumoCash process${RESET}\n"
    kill -9 $(pgrep lumocashd)
fi
if [ -d "/root/lumocash" ]; then
    rm -r lumocash
    printf "${RED}Removed old LumoCash coredir${RESET}\n"
fi
if [ -d "/root/.lumocashcore" ]; then
    rm -r .lumocashcore
    printf "${RED}Removed old LumoCash datadir${RESET}\n"
fi

printf "${GREEN}Downloading and setting up a new wallet instance${RESET}\n"

mkdir /root/lumocash && cd /root/lumocash
wget "https://github.com/LumoCash2018/LumoCash/releases/download/${RELEASE}/LumoCash-${RELEASE}-linux.zip"
unzip LumoCash-v1.0.1.1-linux.zip
rm -r lumocash-qt && rm -r LumoCash-${RELEASE}-linux.zip

chmod ugo+x lumocashd && chmod ugo+x lumocash-cli && chmod ugo+x lumocash-tx

printf "${GREEN}Setting up ${MNNAME}${RESET}\n"

cd /root/
mkdir /root/.lumocashcore

cat <<EOF > /root/.lumocashcore/lumocash.conf
rpcuser=LumoCash
rpcpassword=${PASS}
rpcallowip=127.0.0.1
#----------------------------
listen=1
server=1
daemon=1
maxconnections=64
#----------------------------
masternode=1
masternodeprivkey=${MNKEY}
externalip=${VPSIP}
EOF

printf "${GREEN}Starting up LumoCash Daemon${RESET}\n"

cd /root/lumocash
./lumocashd
sudo ufw disable
sleep 5

printf "${GREEN}Installing Sentinel${RESET}\n"

cd /root/.lumocashcore && sudo git clone https://github.com/LumoCash2018/Sentinel sentinel
cd /root/.lumocashcore/sentinel && mkdir /root/.lumocashcore/sentinel/database
virtualenv ./venv && ./venv/bin/pip install -r requirements.txt
echo "lumocash_conf=/root/.lumocashcore/lumocash.conf" >> /root/.lumocashcore/sentinel/sentinel.conf

printf "${GREEN}Adding Crontab${RESET}\n"
crontab -l > tempcron
echo "* * * * * cd /root/.lumocashcore/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> tempcron
echo "@reboot /bin/sleep 20 ; /root/lumocash/lumocashd -daemon &" >> tempcron
crontab tempcron
rm tempcron

SENTINEL_DEBUG=1 ./venv/bin/python bin/sentinel.py
sleep 15

printf "${GREEN}==================================================================${RESET}\n"
printf "${GREEN}Masternode status:\n"
~/lumocash/lumocash-cli masternode status
printf "${RESET}"
printf "${GREEN}If you get \"Masternode not in masternode list\" status, 
you just have to start your Masternode from your local wallet and the status will change${RESET}\n"
printf "${GREEN}Paste the following line into masternode.conf of your desktop wallet:${RESET}\n\n"
printf "${RED}${MNNAME} ${VPSIP}:${PORT} ${MNKEY} ${MNTX} ${MNTXI}${RESET}\n\n"
printf "${GREEN}Installed with VPS IP ${RED}${VPSIP}${GREEN} on port ${RED}${PORT}${RESET}\n"
printf "${GREEN}Installed with Masternode Key ${RED}${MNKEY}${RESET}\n"
printf "${GREEN}Installed with Masternode TXID ${RED}${MNTX}${GREEN} index ${RED}${MNTXI}${RESET}\n"
printf "${GREEN}Installed with RPCUser=${RED}LumoCash${RESET}\n"
printf "${GREEN}Installed with RPCPassword=${RED}${PASS}${RESET}\n"
printf "${GREEN}==================================================================${RESET}\n"
