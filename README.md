## What is this?
This project is responsible for configuring and running EOS nodes. It is smart enough to create as much EOS nodes as wanted.

It is more of a dev resource which makes developing and testing these projects easier using `docker-compose`.

## Prerequisites
 - Docker Engine and Docker Compose  (tested on Ubuntu and macOS, Docker 18.06.0-ce and docker-compose 1.22.0). In order to download the images required to run the project, access to internet is needed. Images could also take a considerable amount of disk space, make sure to have at least 30GB free.

## EOS Blockchain
EOSIO is software that introduces a blockchain architecture designed to enable vertical and horizontal scaling of decentralized applications. It comes with a number of programs. The primary ones that you will use, and the ones that are covered here, are:

- nodeos (node + eos = nodeos) - the core EOSIO node daemon that can be configured with plugins to run a node. Example uses are block production, dedicated API endpoints, and local development.
- cleos (cli + eos = cleos) - command line interface to interact with the blockchain and to manage wallets
- keosd (key + eos = keosd) - component that securely stores EOSIO keys in wallets. 

For more information: https://eos.io/

## Configuration     
- `up.sh`: This is a script that orchestrate all the configuration that needs to be done prior running the nodes and also, as the name states, starts everything up. At this file, there is configuration for: a default wallet inside keosd node; deploying the eosio.bios smart contract; and all the initial setup for all nodeos instances required.

## Adding / Removing nodes
During the execution of the `up.sh`script, it will be asked how many extra nodes is required to be configured. Just follow the options using the script.

## Network 
Docker compose file is configured to startup all the nodes under the subnet 172.15.0.0/16. If you are running locally you may also refer to the nodes and servers using **localhost**.

## Running Locally
Run: `./up.sh` in the project folder.
Now:
 - **Keosd nodes**:
    - http://172.15.0.99:8899
    
 - **Nodeos nodes**:
    - http://172.15.0.10:8888 - Main/Producer EOS node
    
- **Extra Nodeos nodes**:
    - http://172.15.0.10:8889 - The extra nodes will sum 1 to the port value.

You may test if it running by accessing: http://localhost:8888/v1/chain/get_info. Change the port value to see if the other nodes are running.

## Environment Variables
For a full list, please see the environment variables which are set in the `docker-compose.yml` files for each application.  

**Locally:** Modify the `docker-compose.yml` files `environment` section to add new variables. Check also the variables declared inside the `up.sh` file.

**Server:** Set variables based on above files.

## Testing
If the Hello contract was deployed during the configuration, an easy way to test if it works is to execute the following command:

```
docker exec -it eos-main-node cleos --wallet-url http://172.15.0.99:8899 push action hello hi '["Rodrigo"]' -p hello@active
```

## Clean up
In order to clean up everything, just run the `./up.sh` and select the option 3.

## Folder structure
    .
    ├── .vscode                        # VS Code config files (recommended editor)
    ├── eos                            # Folder holds all files related to EOS
    ├── .gitignore                     # Files which should not be checked into git
    ├── docker-compose.yml.template    # docker-compose orchestration file
    ├── up.sh                          # Start-up script
    ├── down.sh                        # Script used to stop all nodes and removing all files created.
    └── README.md
