#!/bin/bash

CHAINID="${CHAIN_ID:-evmos_9002-1}"
BASE_DENOM="aevmos"
MONIKER="localtestnet"
# Remember to change to other types of keyring like 'file' in-case exposing to outside world,
# otherwise your balance will be wiped quickly
# The keyring test does not require private key to steal tokens from you
KEYRING="test"
KEYALGO="eth_secp256k1"
LOGLEVEL="info"
# Set dedicated home directory for the evmosd instance
HOMEDIR="$(cd $(dirname $0) && pwd -P)/build/.evmosd"
NODE0DIR="${HOMEDIR}/node0"
NODE1DIR="${HOMEDIR}/node1"
NODE2DIR="${HOMEDIR}/node2"
NODE3DIR="${HOMEDIR}/node3"
# to trace evm
#TRACE="--trace"
TRACE=""

# feemarket params basefee
BASEFEE=1000000000

# Path variables
CONFIG=$NODE0DIR/config/config.toml
APP_TOML=$NODE0DIR/config/app.toml
GENESIS=$NODE0DIR/config/genesis.json
TMP_GENESIS=$NODE0DIR/config/tmp_genesis.json

# validate dependencies are installed
command -v jq >/dev/null 2>&1 || {
	echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"
	exit 1
}

# used to exit on first error (any non-zero exit code)
set -e

# Parse input flags
install=true
build_docker=true
overwrite=""

while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
	-y)
		echo "Flag -y passed -> Overwriting the previous chain data."
		overwrite="y"
		shift # Move past the flag
		;;
	-n)
		echo "Flag -n passed -> Not overwriting the previous chain data."
		overwrite="n"
		shift # Move past the argument
		;;
	--no-install)
		echo "Flag --no-install passed -> Skipping installation of the evmosd binary."
		install=false
		shift # Move past the flag
		;;
	--no-build-docker)
		echo "Flag --no-build-docker passed -> Skipping docker build."
		build_docker=false
		shift # Move past the flag
		;;
	*)
		echo "Unknown flag passed: $key -> Exiting script!"
		exit 1
		;;
	esac
done

if [[ $install == true ]]; then
	# (Re-)install daemon
    make install
fi

if [[ $build_docker == true ]]; then
	make build-docker-goleveldb
fi

# User prompt if neither -y nor -n was passed as a flag
# and an existing local node configuration is found.
if [[ $overwrite = "" ]]; then
	if [ -d "$HOMEDIR" ]; then
		printf "\nAn existing folder at '%s' was found. You can choose to delete this folder and start a new local node with new keys from genesis. When declined, the existing local node is started. \n" "$HOMEDIR"
		echo "Overwrite the existing configuration and start a new local node? [y/n]"
		read -r overwrite
	else
		overwrite="y"
	fi
fi

# Setup local node if overwrite is set to Yes, otherwise skip setup
if [[ $overwrite == "y" || $overwrite == "Y" ]]; then
	# Remove the previous folder
	rm -rf "$HOMEDIR"

	# Set client config
	evmosd config set client chain-id "$CHAINID" --home "$NODE0DIR"
	evmosd config set client keyring-backend "$KEYRING" --home "$NODE0DIR"

	# myKey address 0x7cb61d4117ae31a12e393a1cfa3bac666481d02e | evmos10jmp6sgh4cc6zt3e8gw05wavvejgr5pwjnpcky
	VAL_KEY="mykey"
	VAL_MNEMONIC="gesture inject test cycle original hollow east ridge hen combine junk child bacon zero hope comfort vacuum milk pitch cage oppose unhappy lunar seat"

	# dev0 address 0xc6fe5d33615a1c52c08018c47e8bc53646a0e101 | evmos1cml96vmptgw99syqrrz8az79xer2pcgp84pdun
	USER1_KEY="dev0"
	USER1_MNEMONIC="copper push brief egg scan entry inform record adjust fossil boss egg comic alien upon aspect dry avoid interest fury window hint race symptom"

	# dev1 address 0x963ebdf2e1f8db8707d05fc75bfeffba1b5bac17 | evmos1jcltmuhplrdcwp7stlr4hlhlhgd4htqh3a79sq
	USER2_KEY="dev1"
	USER2_MNEMONIC="maximum display century economy unlock van census kite error heart snow filter midnight usage egg venture cash kick motor survey drastic edge muffin visual"

	# dev2 address 0x40a0cb1C63e026A81B55EE1308586E21eec1eFa9 | evmos1gzsvk8rruqn2sx64acfsskrwy8hvrmafqkaze8
	USER3_KEY="dev2"
	USER3_MNEMONIC="will wear settle write dance topic tape sea glory hotel oppose rebel client problem era video gossip glide during yard balance cancel file rose"

	# dev3 address 0x498B5AeC5D439b733dC2F58AB489783A23FB26dA | evmos1fx944mzagwdhx0wz7k9tfztc8g3lkfk6rrgv6l
	USER4_KEY="dev3"
	USER4_MNEMONIC="doll midnight silk carpet brush boring pluck office gown inquiry duck chief aim exit gain never tennis crime fragile ship cloud surface exotic patch"

	# Import keys from mnemonics
	echo "$VAL_MNEMONIC" | evmosd keys add "$VAL_KEY" --recover --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$NODE0DIR"
	echo "$USER1_MNEMONIC" | evmosd keys add "$USER1_KEY" --recover --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$NODE0DIR"
	echo "$USER2_MNEMONIC" | evmosd keys add "$USER2_KEY" --recover --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$NODE0DIR"
	echo "$USER3_MNEMONIC" | evmosd keys add "$USER3_KEY" --recover --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$NODE0DIR"
	echo "$USER4_MNEMONIC" | evmosd keys add "$USER4_KEY" --recover --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$NODE0DIR"

	# Set moniker and chain-id for Evmos (Moniker can be anything, chain-id must be an integer)
	evmosd init $MONIKER -o --chain-id "$CHAINID" --home "$NODE0DIR"
    evmosd init $MONIKER -o --chain-id "$CHAINID" --home "$NODE1DIR"
    evmosd init $MONIKER -o --chain-id "$CHAINID" --home "$NODE2DIR"
    evmosd init $MONIKER -o --chain-id "$CHAINID" --home "$NODE3DIR"
	# Change parameter token denominations to $BASE_DENOM
	jq --arg base_denom "$BASE_DENOM" '.app_state["staking"]["params"]["bond_denom"]=$base_denom' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq --arg base_denom "$BASE_DENOM" '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]=$base_denom' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	# When upgrade to cosmos-sdk v0.47, use gov.params to edit the deposit params
	jq --arg base_denom "$BASE_DENOM" '.app_state["gov"]["params"]["min_deposit"][0]["denom"]=$base_denom' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
	jq --arg base_denom "$BASE_DENOM" '.app_state["inflation"]["params"]["mint_denom"]=$base_denom' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	# Set gas limit in genesis
	jq '.consensus_params["block"]["max_gas"]="10000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	# Set base fee in genesis
	jq '.app_state["feemarket"]["params"]["base_fee"]="'${BASEFEE}'"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

	if [[ $1 == "pending" ]]; then
		if [[ "$OSTYPE" == "darwin"* ]]; then
			sed -i '' 's/timeout_propose = "3s"/timeout_propose = "30s"/g' "$CONFIG"
			sed -i '' 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "5s"/g' "$CONFIG"
			sed -i '' 's/timeout_prevote = "1s"/timeout_prevote = "10s"/g' "$CONFIG"
			sed -i '' 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "5s"/g' "$CONFIG"
			sed -i '' 's/timeout_precommit = "1s"/timeout_precommit = "10s"/g' "$CONFIG"
			sed -i '' 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "5s"/g' "$CONFIG"
			sed -i '' 's/timeout_commit = "5s"/timeout_commit = "150s"/g' "$CONFIG"
			sed -i '' 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "150s"/g' "$CONFIG"
		else
			sed -i 's/timeout_propose = "3s"/timeout_propose = "30s"/g' "$CONFIG"
			sed -i 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "5s"/g' "$CONFIG"
			sed -i 's/timeout_prevote = "1s"/timeout_prevote = "10s"/g' "$CONFIG"
			sed -i 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "5s"/g' "$CONFIG"
			sed -i 's/timeout_precommit = "1s"/timeout_precommit = "10s"/g' "$CONFIG"
			sed -i 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "5s"/g' "$CONFIG"
			sed -i 's/timeout_commit = "5s"/timeout_commit = "150s"/g' "$CONFIG"
			sed -i 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "150s"/g' "$CONFIG"
		fi
	fi

	# enable prometheus metrics and all APIs for dev node
	if [[ "$OSTYPE" == "darwin"* ]]; then
		sed -i '' 's/prometheus = false/prometheus = true/' "$CONFIG"
        sed -i '' 's~laddr = "tcp://127.0.0.1:26657"~laddr = "tcp://0.0.0.0:26657"~' "$CONFIG"	
		sed -i '' 's/prometheus-retention-time = 0/prometheus-retention-time  = 1000000000000/g' "$APP_TOML"
		sed -i '' 's/enabled = false/enabled = true/g' "$APP_TOML"
		sed -i '' 's/enable = false/enable = true/g' "$APP_TOML"
		# Don't enable Rosetta API by default
		grep -q -F '[rosetta]' "$APP_TOML" && sed -i '' '/\[rosetta\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable memiavl by default
		grep -q -F '[memiavl]' "$APP_TOML" && sed -i '' '/\[memiavl\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable versionDB by default
		grep -q -F '[versiondb]' "$APP_TOML" && sed -i '' '/\[versiondb\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
	else
		sed -i 's/prometheus = false/prometheus = true/' "$CONFIG"
        sed -i 's~laddr = "tcp://127.0.0.1:26657"~laddr = "tcp://0.0.0.0:26657"~' "$CONFIG"
		sed -i 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"
		sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
		sed -i 's/enable = false/enable = true/g' "$APP_TOML"
		# Don't enable Rosetta API by default
		grep -q -F '[rosetta]' "$APP_TOML" && sed -i '/\[rosetta\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable memiavl by default
		grep -q -F '[memiavl]' "$APP_TOML" && sed -i '/\[memiavl\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable versionDB by default
		grep -q -F '[versiondb]' "$APP_TOML" && sed -i '/\[versiondb\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
	fi
# Change proposal periods to pass within a reasonable time for local testing
	sed -i.bak 's/"max_deposit_period": "172800s"/"max_deposit_period": "30s"/g' "$GENESIS"
	sed -i.bak 's/"voting_period": "172800s"/"voting_period": "30s"/g' "$GENESIS"
	sed -i.bak 's/"expedited_voting_period": "86400s"/"expedited_voting_period": "15s"/g' "$GENESIS"

	# set custom pruning settings
	sed -i.bak 's/pruning = "default"/pruning = "custom"/g' "$APP_TOML"
	sed -i.bak 's/pruning-keep-recent = "0"/pruning-keep-recent = "2"/g' "$APP_TOML"
	sed -i.bak 's/pruning-interval = "0"/pruning-interval = "10"/g' "$APP_TOML"
    sed -i.bak 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/g' "$APP_TOML"
    sed -i.bak 's/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/g' "$APP_TOML"

	# Allocate genesis accounts (cosmos formatted addresses)
	evmosd add-genesis-account "$(evmosd keys show "$VAL_KEY" -a --keyring-backend "$KEYRING" --home "$NODE0DIR")" 100000000000000000000000000$BASE_DENOM --keyring-backend "$KEYRING" --home "$NODE0DIR"
	evmosd add-genesis-account "$(evmosd keys show "$USER1_KEY" -a --keyring-backend "$KEYRING" --home "$NODE0DIR")" 1000000000000000000000$BASE_DENOM --keyring-backend "$KEYRING" --home "$NODE0DIR"
	evmosd add-genesis-account "$(evmosd keys show "$USER2_KEY" -a --keyring-backend "$KEYRING" --home "$NODE0DIR")" 1000000000000000000000$BASE_DENOM --keyring-backend "$KEYRING" --home "$NODE0DIR"
	evmosd add-genesis-account "$(evmosd keys show "$USER3_KEY" -a --keyring-backend "$KEYRING" --home "$NODE0DIR")" 1000000000000000000000$BASE_DENOM --keyring-backend "$KEYRING" --home "$NODE0DIR"
	evmosd add-genesis-account "$(evmosd keys show "$USER4_KEY" -a --keyring-backend "$KEYRING" --home "$NODE0DIR")" 1000000000000000000000$BASE_DENOM --keyring-backend "$KEYRING" --home "$NODE0DIR"

	# Sign genesis transaction
	evmosd gentx "$VAL_KEY" 1000000000000000000000$BASE_DENOM --gas-prices ${BASEFEE}$BASE_DENOM --keyring-backend "$KEYRING" --chain-id "$CHAINID" --home "$NODE0DIR"
	## In case you want to create multiple validators at genesis
	## 1. Back to `evmosd keys add` step, init more keys
	## 2. Back to `evmosd add-genesis-account` step, add balance for those
	## 3. Clone this ~/.evmosd home directory into some others, let's say `~/.clonedEvmosd`
	## 4. Run `gentx` in each of those folders
	## 5. Copy the `gentx-*` folders under `~/.clonedEvmosd/config/gentx/` folders into the original `~/.evmosd/config/gentx`

	# Collect genesis tx
	evmosd collect-gentxs --home "$NODE0DIR"

	# Run this to ensure everything worked and that the genesis file is setup correctly
	evmosd validate-genesis --home "$NODE0DIR"

	if [[ $1 == "pending" ]]; then
		echo "pending mode is on, please wait for the first block committed."
	fi
fi

docker run \
	-p 1317:1317 \
	-p 26656:26656 \
	-p 26657:26657 \
	-p 8545:8545 \
	-p 8546:8546 \
	-p 9090:9090 \
    --name evmos-node0 \
	-d \
	--rm \
	-v $NODE0DIR:/home/evmos/.evmosd \
	tharsishq/evmos:latest \
	evmosd start \
    --metrics "$TRACE" \
    --log_level $LOGLEVEL \
    --minimum-gas-prices=0.0001$BASE_DENOM \
    --json-rpc.api eth,txpool,personal,net,debug,web3 \
    --home "/home/evmos/.evmosd" \
    --chain-id "$CHAINID"

SEEDS=$(cat $GENESIS | jq '.app_state.genutil.gen_txs.[0].body.memo')
SEEDS=${SEEDS:0:41}
echo $SEEDS

cp $CONFIG $CONFIG.bak
EXTERNAL_ADDRESS="evmos-node0:26656"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # sed -i '' 's/external_address = ""/external_address = "'$EXTERNAL_ADDRESS'"/' "$CONFIG.bak"
    sed -i '' 's/seeds = ""/seeds = '$SEEDS'@evmos-node0:26656"/' "$CONFIG.bak"
else
    # sed -i 's/external_address = ""/external_address = "'$EXTERNAL_ADDRESS'"/' "$CONFIG.bak"
    sed -i 's/seeds = ""/seeds = '$SEEDS'@'$EXTERNAL_ADDRESS'"/' "$CONFIG.bak"
fi

cp $CONFIG.bak $NODE1DIR/config/config.toml
cp $APP_TOML $NODE1DIR/config/
cp $GENESIS $NODE1DIR/config/

docker run \
	-p 11317:1317 \
	-p 36656:26656 \
	-p 36657:26657 \
	-p 18545:8545 \
	-p 18546:8546 \
	-p 19090:9090 \
	--name evmos-node1 \
    --link evmos-node0:evmos-node0 \
	-d \
	--rm \
	-v $NODE1DIR:/home/evmos/.evmosd \
	tharsishq/evmos:latest \
	evmosd start \
    --metrics "$TRACE" \
    --log_level $LOGLEVEL \
    --minimum-gas-prices=0.0001$BASE_DENOM \
    --json-rpc.api eth,txpool,personal,net,debug,web3 \
    --home "/home/evmos/.evmosd" \
    --chain-id "$CHAINID"

cp $CONFIG.bak $NODE2DIR/config/config.toml
cp $APP_TOML $NODE2DIR/config/
cp $GENESIS $NODE2DIR/config/

docker run \
	-p 21317:1317 \
	-p 46656:26656 \
	-p 46657:26657 \
	-p 28545:8545 \
	-p 28546:8546 \
	-p 29090:9090 \
	--name evmos-node2 \
    --link evmos-node0:evmos-node0 \
	-d \
	--rm \
	-v $NODE2DIR:/home/evmos/.evmosd \
	tharsishq/evmos:latest \
	evmosd start \
    --metrics "$TRACE" \
    --log_level $LOGLEVEL \
    --minimum-gas-prices=0.0001$BASE_DENOM \
    --json-rpc.api eth,txpool,personal,net,debug,web3 \
    --home "/home/evmos/.evmosd" \
    --chain-id "$CHAINID"

cp $CONFIG.bak $NODE3DIR/config/config.toml
cp $APP_TOML $NODE3DIR/config/
cp $GENESIS $NODE3DIR/config/

docker run \
	-p 31317:1317 \
	-p 56656:26656 \
	-p 56657:26657 \
	-p 38545:8545 \
	-p 38546:8546 \
	-p 39090:9090 \
	--name evmos-node3 \
    --link evmos-node0:evmos-node0 \
	-d \
	--rm \
	-v $NODE3DIR:/home/evmos/.evmosd \
	tharsishq/evmos:latest \
	evmosd start \
    --metrics "$TRACE" \
    --log_level $LOGLEVEL \
    --minimum-gas-prices=0.0001$BASE_DENOM \
    --json-rpc.api eth,txpool,personal,net,debug,web3 \
    --home "/home/evmos/.evmosd" \
    --chain-id "$CHAINID"