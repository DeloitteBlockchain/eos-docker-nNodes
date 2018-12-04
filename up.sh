#!/usr/bin/env bash
set -o errexit
# set -o xtrace

HTTP_PORT=8889
P2P_PORT=9877
IP_ADDRESS_COUNT=11

EOS_IMAGE_VERSION='v1.4.4'
EOS_PLUGINS='--plugin eosio::chain_api_plugin --plugin eosio::net_api_plugin --plugin eosio::history_plugin --plugin eosio::history_api_plugin'
EOS_P2P_ENDPOINTS='--p2p-peer-address 172.15.0.10:9876'
EOS_NODE_NAMES=''

EOS_NODES_FILE=eos_nodes.txt

export URL_KEOSD=http://172.15.0.99:8899

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

function dc() {
  docker-compose --log-level ERROR up -d --build "$@"
}

function keos() {
  docker exec -it eos-keosd cleos --wallet-url ${URL_KEOSD} "$@"
}

function nodeos() {
  docker exec -it eos-main-node "$@"
}

function cleos() {
  docker exec -it eos-main-node cleos "$@"
}

function cleosw() {
  docker exec -it eos-main-node cleos --wallet-url ${URL_KEOSD} "$@"
}

function eosiocpp() {
  docker exec -it eos-main-node eosiocpp "$@"
}

function resetDockerFile() {
  rm -f docker-compose.yml
  cp docker-compose.yml.template docker-compose.yml

  # Replacing the image with the correct one
  sed -i.bak s/EOS_IMAGE_VERSION/eosio\\/eos:$EOS_IMAGE_VERSION/g docker-compose.yml
  sed -i.bak s/EOS_DEV_IMAGE_VERSION/eosio\\/eos-dev:$EOS_IMAGE_VERSION/g docker-compose.yml

  rm -f docker-compose.yml.bak
}

function generateDockerNode() {
  echo 'Generating docker node' $1

  CURRENT_P2P='--p2p-peer-address 172.15.0.'$IP_ADDRESS_COUNT:$P2P_PORT
  LOCAL_EOS_P2P_ENDPOINTS=${EOS_P2P_ENDPOINTS/$CURRENT_P2P/}

  echo '
  eos-node_'$1':
    image: eosio/eos:'$EOS_IMAGE_VERSION'
    command: nodeos --producer-name '$1' --max-transaction-time=250 '$EOS_PLUGINS' --filter-on=* --http-server-address 0.0.0.0:'$HTTP_PORT' --p2p-listen-endpoint 0.0.0.0:'$P2P_PORT $LOCAL_EOS_P2P_ENDPOINTS' --config-dir /mnt/dev/config --data-dir /mnt/dev/data --http-validate-host false --signature-provider $NODE_'$1'_KEY
    ports:
      - "'$HTTP_PORT':8889"
      - "'$P2P_PORT':9877"
    volumes:
      - ./eos/nodeos_'$1'/data:/mnt/dev/data
      - ./eos/nodeos_'$1'/config:/mnt/dev/config
    networks:
      eos_net:
        ipv4_address: "172.15.0.'$IP_ADDRESS_COUNT'"' >> docker-compose.yml

    HTTP_PORT=$((HTTP_PORT+1))
    P2P_PORT=$((P2P_PORT+1))
    IP_ADDRESS_COUNT=$((IP_ADDRESS_COUNT+1))
    EOS_NODE_NAMES="$EOS_NODE_NAMES $1"
}

function generateP2PAddresses() {

  COUNT=0
  while [ "$@" != "$COUNT" ]
  do
    EOS_P2P_ENDPOINTS="$EOS_P2P_ENDPOINTS --p2p-peer-address 172.15.0.$((IP_ADDRESS_COUNT + $COUNT)):$((P2P_PORT + $COUNT))"

    COUNT=$((COUNT+1))
  done
}

function configureDockerEOS() {
  echo 'Welcome to EOS Docker configuration script.'
  echo 'The default configuration comes with one KEOSD node (wallet) and one CLEOS node (EOS node)'
  
  resetDockerFile

  read -p 'Do you want to add more CLEOS nodes? (Y/N) ' MORE_NODES
  if [ "$MORE_NODES" != "${MORE_NODES#[Yy]}" ] ;then

    read -p 'How many EOS nodes do you want? (1 - 100) ' NODE_COUNT

    generateP2PAddresses $NODE_COUNT

    COUNT=0
    while [ "$NODE_COUNT" != "$COUNT" ]
    do
      echo 'Configuring node ' $((COUNT+1))

      COUNT=$((COUNT+1))

      ### Name should be less than 13 characters and only contains the following symbol .12345abcdefghijklmnopqrstuvwxyz
      generateDockerNode $(head /dev/urandom | env LC_CTYPE=C tr -dc a-z1-5 | head -c 5)

      sleep 1
    done
  fi

  echo 'Docker configuration done'
}

function deployTokenContract() {
  echo 'Deploying default token contract'

  # Creating a key pair for token contract
  cleos create key --file /mnt/dev/keystore/token.keystore

  # Importing token key the wallet
  export TOKEN_PRI_KEY=$(grep 'Private key: ' eos/keystore/token.keystore | sed 's/Private key: //g')
  cleosw wallet import --private-key ${TOKEN_PRI_KEY}

  # Creating an account
  export TOKEN_PUB_KEY=$(grep 'Public key: ' eos/keystore/token.keystore | sed 's/Public key: //g')
  cleosw create account eosio eosio.token ${TOKEN_PUB_KEY}

  # Deploying the eosio.token contract
  cleosw set contract eosio.token /opt/eosio/contracts/eosio.token -p eosio.token@active

  # Set the threshold of the tokens in your account and the token name
  cleosw push action eosio.token create '{"issuer":"eosio.token", "maximum_supply": "1000000000.0000 SYS"}' -p eosio.token@active

  # Issue eosio.token account tokens in order to transfer to other accounts
  cleosw push action eosio.token issue '{"to":"eosio.token", "quantity": "100000000.0000 SYS", "memo": "issue"}' -p eosio.token@active
}

function deployHelloContract() {
  echo 'Deploying Hello contract'

  # Creating a key pair for hello contract
  cleos create key --file /mnt/dev/keystore/hello.keystore

  # Importing hello key the wallet
  export HELLO_PRI_KEY=$(grep 'Private key: ' eos/keystore/hello.keystore | sed 's/Private key: //g')
  cleosw wallet import --private-key ${HELLO_PRI_KEY}

  # Creating an account
  export HELLO_PUB_KEY=$(grep 'Public key: ' eos/keystore/hello.keystore | sed 's/Public key: //g')
  cleosw create account eosio hello ${HELLO_PUB_KEY}

  # Compiling hello contract
  eosiocpp -g /contracts/hello/hello.abi /contracts/hello/hello.cpp
  eosiocpp -o /contracts/hello/hello.wast /contracts/hello/hello.cpp

  # Deploying the Test contract
  cleosw set contract hello /contracts/hello -p hello@active

  # Testing the contract
  cleosw push action hello hi '["Rodrigo"]' -p hello@active

  sleep 2
}

function stopEOS() {
  source down.sh
}

function stopRemoveEOS() {
  stopEOS
  
  # Removing old files
  rm -rf eos/wallet/
  rm -rf eos/logs/
  rm -rf eos/nodeos*
  rm -rf eos/keystore
  rm -f eos_nodes.txt
  rm -f docker-compose.yml
}

function startEOS() {
  if [ -f "$EOS_NODES_FILE" ]
  then
    EOS_NODE_NAMES=$(<eos_nodes.txt)

    for i in $EOS_NODE_NAMES
    do
      export NODE_${i}_PUB_KEY=$(grep 'Public key: ' eos/keystore/node_${i}.keystore | sed 's/Public key: //g')
      export NODE_${i}_PRI_KEY=$(grep 'Private key: ' eos/keystore/node_${i}.keystore | sed 's/Private key: //g')

      REF_PUB_KEY=NODE_${i}_PUB_KEY
      REF_PRI_KEY=NODE_${i}_PRI_KEY

      export NODE_${i}_KEY=${!REF_PUB_KEY}=KEY:${!REF_PRI_KEY}
    done
  fi

  dc

  docker-compose logs -f
}

function configureEOS() {
  echo 'Welcome to EOS start & configuration script.'

  # Running the first main nodes
  dc eos-main-node eos-keosd

  # Waiting for the nodes to be up
  sleep 5s

  # Creating the wallet
  keos wallet create --file /opt/eosio/wallet/pass.txt

  # Importing the private key.
  keos wallet import --private-key 5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3

  # Deploying the eosio.bios contract
  cleosw set contract eosio /contracts/eosio.bios

  #### Token Contract ####
  read -p 'Do you want to deploy the default token contract? (Y/N) ' TOKEN_CONTRACT
  if [ "$TOKEN_CONTRACT" != "${TOKEN_CONTRACT#[Yy]}" ] ;then
    deployTokenContract
  fi

  #### Hello Contract ####
  read -p 'Do you want to deploy the Hello contract? (Y/N) ' HELLO_CONTRACT
  if [ "$HELLO_CONTRACT" != "${HELLO_CONTRACT#[Yy]}" ] ;then
    deployHelloContract
  fi

  echo $EOS_NODE_NAMES > $EOS_NODES_FILE

  #### Configuring extra nodes ####
  for i in $EOS_NODE_NAMES
  do
      echo 'Configuring node ' $i
      # Creating a new key for the node
      cleos create key --file /mnt/dev/keystore/node_$i.keystore

      export NODE_${i}_PUB_KEY=$(grep 'Public key: ' eos/keystore/node_${i}.keystore | sed 's/Public key: //g')
      export NODE_${i}_PRI_KEY=$(grep 'Private key: ' eos/keystore/node_${i}.keystore | sed 's/Private key: //g')

      REF_PUB_KEY=NODE_${i}_PUB_KEY
      REF_PRI_KEY=NODE_${i}_PRI_KEY

      # Importing the new private key
      cleosw wallet import --private-key ${!REF_PRI_KEY}

      # Create a new account for the new node with the public key
      cleosw create account eosio node${i} ${!REF_PUB_KEY}

      export NODE_${i}_KEY=${!REF_PUB_KEY}=KEY:${!REF_PRI_KEY}

      # Running node
      dc eos-node_${i}

      sleep 1s
  done

  echo 'All configuration has been completed. Showing dockers logs now'
  sleep 1s

  docker-compose logs -f
}

function showMenu() {
  echo 'This the UP script for EOS project. Please see the options below:'
  echo ''

  PS3='Please enter your choice: '
  options=("Configure EOS nodes" "Start Project" "Clean Project" "Quit")
  select opt in "${options[@]}"
  do
      case $opt in
          "Configure EOS nodes")
              stopRemoveEOS
              configureDockerEOS
              configureEOS
              break
              ;;
          "Start Project")
              stopEOS
              startEOS
              break
              ;;
          "Clean Project")
              stopRemoveEOS
              break
              ;;
          "Quit")
              break
              ;;
          *) echo "invalid option $REPLY";;
      esac
  done
}

showMenu

