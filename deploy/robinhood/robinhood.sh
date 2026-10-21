#!/usr/bin/env bash
# CYBER on Robinhood Chain: deploy the token + CyberTokenController and wire the Robinhood <-> Ethereum pathway.
# Bytecode is compiled from the Basescan-verified sources of the Base deployment (sources/), so every contract is
# byte-identical to Base and verifiable with the same standard-JSON input. See README.md for the run order.
set -euo pipefail
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
cd "$(dirname "$0")"

RH_RPC=${RH_RPC:-https://rpc.mainnet.chain.robinhood.com}
ETH_RPC=${ETH_RPC:-https://ethereum-rpc.publicnode.com}
SOLC_DIR=${SOLC_DIR:-$HOME/.svm}

RH_EID=30416
ETH_EID=30101
DEPLOYER=0x0e0bE581B17684f849AF6964D731FCe0F7d366BD
TOKEN_DEPLOYER=0xE906b91103D216420F7AE13b29fde73ce9c206cD
DELEGATE=0x7884f7F04F994da14302a16Cf15E597e31eebECf
ETH_SAFE=0x455DB34c99A866489F3ac63fa2F068c726BC286b
FACTORY=0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f
TOKEN=0x14778860E937f509e651192a90589dE711Fb88a9
CONTROLLER=0x3cBfDaDA8abCb43A42eAEd1B88e72B06eb2523da
ADAPTER=0xCB07992DE144bDeE56fDb66Fff2454B43243b052
RH_ENDPOINT=0x6F475642a6e85809B1c36Fa62763669b1b48DD5B
ETH_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
RH_SEND_LIB=0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7
RH_RECV_LIB=0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043
ETH_SEND_LIB=0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
ETH_RECV_LIB=0xc02Ab410f0734EFa3F14628780e6e695156024C2
# Required DVNs (LayerZero Labs + Nethermind), ascending as ULN302 requires.
RH_DVNS=(0x0ffe02df012299a370d5dd69298a5826eacafdf8 0xd01ae6905d48315f7be10c7330aecf8360ef5b12)
ETH_DVNS=(0x589dEDbD617e0CBcB916A9223F4d1300c294236b 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5)
ETH_CONF=15
RH_CONF=20
# Executor lzReceive gas. Into Robinhood a mint costs 159,482 when the recipient has delegated votes, so Base's
# 150k is not enough there; into Ethereum an unlock costs 81,182.
GAS_TO_RH=200000
GAS_TO_ETH=150000
SALT=$(cast keccak Cyber)
# keccak256 of Base's deployed creation code; a mismatch means the sources or the compiler changed.
HASH_FACTORY=0xe575db2b1f2d65b4b7b63c4bebfe02a6273adea859f5a4c1186f42a981564594
HASH_TOKEN=0x3bc785c35f3c63f80dcddd03bdc8b3776adbc46d2e98fb10883c1f0f5f73d4b2
HASH_CONTROLLER=0x553f031a41aa86b4460dee982a1668dfaac8974e061ffde60d357bef60d7a8f0

MODE=live
RH=$RH_RPC
ETH=$ETH_RPC
GASLOG=

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "==> $*"; }
lc() { tr 'A-F' 'a-f' <<<"$1"; }
eq() { [ "$(lc "$1")" = "$(lc "$2")" ]; }
need() { eq "$1" "$2" || die "$3: got $1, want $2"; }
num() { awk '{print $1}' <<<"$1"; }
b32() { echo "0x000000000000000000000000$(lc "${1#0x}")"; }
csv() { local IFS=,; echo "[$*]"; }
uln() { cast abi-encode 'f((uint64,uint8,uint8,uint8,address[],address[]))' "($1,2,0,0,$2,[])"; }
opt() { printf '0x0003010011010000000000000000000000%010x\n' "$1"; }
code_size() { local c; c=$(cast code "$1" --rpc-url "$2"); echo $(((${#c} - 2) / 2)); }
supply() { num "$(cast call $TOKEN 'totalSupply()(uint256)' --rpc-url $RH)"; }

confirm() {
    [ "$MODE" = live ] || return 0
    [ "${YES:-}" = 1 ] && { log "$1"; return 0; }
    read -r -p "==> $1 -- send? [y/N] " a </dev/tty
    [ "$a" = y ] || die "aborted"
}

key_of() {
    case $(lc "$1") in
    $(lc $DEPLOYER)) echo "${DEPLOYER_PK:?set DEPLOYER_PK}" ;;
    $(lc $TOKEN_DEPLOYER)) echo "${TOKEN_DEPLOYER_PK:?set TOKEN_DEPLOYER_PK}" ;;
    $(lc $DELEGATE)) echo "${DELEGATE_PK:?set DELEGATE_PK}" ;;
    *) die "no key for $1" ;;
    esac
}

check_key() { need "$(cast wallet address --private-key "$(key_of "$1")")" "$1" "private key for $1"; }

# send <rpc> <from> <cast send args...>  -> receipt json on stdout
send() {
    local rpc=$1 from=$2 r
    shift 2
    if [ "$MODE" = live ]; then
        r=$(cast send --private-key "$(key_of "$from")" --rpc-url "$rpc" "$@" --json)
    else
        r=$(cast send --unlocked --from "$from" --rpc-url "$rpc" "$@" --json)
    fi
    [ "$(jq -r .status <<<"$r")" = 0x1 ] || die "tx reverted: $*"
    [ "$MODE" = live ] && echo "    tx $(jq -r .transactionHash <<<"$r") (block $((16#$(jq -r .blockNumber <<<"$r" | sed 's/^0x//'))))" >&2
    [ -n "$GASLOG" ] && echo "$rpc $from $(jq -r .transactionHash <<<"$r")" >>"$GASLOG"
    echo "$r"
}

build() {
    mkdir -p out
    python3 - "$SOLC_DIR" <<'PY'
import json, subprocess, sys
solc_dir = sys.argv[1]
for name, ver in (("Create2Deployer", "0.8.14"), ("CyberToken", "0.8.14"), ("CyberTokenController", "0.8.22")):
    std = json.load(open(f"sources/{name}.json"))
    std["settings"]["outputSelection"] = {"*": {"*": ["evm.bytecode.object", "evm.deployedBytecode.object"]}}
    out = json.loads(subprocess.run([f"{solc_dir}/{ver}/solc-{ver}", "--standard-json"], input=json.dumps(std),
                                    capture_output=True, text=True, check=True).stdout)
    errors = [e["formattedMessage"] for e in out.get("errors", []) if e["severity"] == "error"]
    if errors:
        sys.exit("\n".join(errors))
    evm = next(c[name]["evm"] for c in out["contracts"].values() if name in c)
    open(f"out/{name}.hex", "w").write("0x" + evm["bytecode"]["object"])
    open(f"out/{name}.runtime.hex", "w").write("0x" + evm["deployedBytecode"]["object"])
PY
    need "$(cast keccak "$(cat out/Create2Deployer.hex)")" $HASH_FACTORY "Create2Deployer creation code"
    need "$(cast keccak "$(cat out/CyberToken.hex)")" $HASH_TOKEN "CyberToken creation code"
    need "$(cast keccak "$(cat out/CyberTokenController.hex)")" $HASH_CONTROLLER "CyberTokenController creation code"
    local args
    args=$(cast abi-encode 'f(address,address,address)' $TOKEN $RH_ENDPOINT $DELEGATE)
    echo -n "$(cat out/CyberTokenController.hex)${args#0x}" >out/controller-initcode.hex
    echo -n "${args#0x}" >out/controller-args.hex
    need "$(cast compute-address --salt "$SALT" --init-code-hash "$(cast keccak "$(cat out/controller-initcode.hex)")" $FACTORY | awk '{print $NF}')" \
        $CONTROLLER "controller CREATE2 address"
    log "build ok: bytecode matches Base, controller lands at $CONTROLLER"
}

check_token_fresh() {
    need "$(cast call $TOKEN 'symbol()(string)' --rpc-url $RH)" '"CYBER"' "token symbol"
    need "$(cast call $TOKEN 'decimals()(uint8)' --rpc-url $RH)" 18 "token decimals"
}

deploy_factory() {
    if [ "$(code_size $FACTORY $RH)" -gt 0 ]; then
        need "$(cast code $FACTORY --rpc-url $RH)" "$(cat out/Create2Deployer.runtime.hex)" "factory runtime"
        return
    fi
    need "$(cast nonce $DEPLOYER --rpc-url $RH)" 0 "deployer nonce ($FACTORY is its nonce-0 address)"
    confirm "Robinhood: $DEPLOYER (nonce 0) deploys Create2Deployer -> $FACTORY"
    need "$(send $RH $DEPLOYER --create "$(cat out/Create2Deployer.hex)" | jq -r .contractAddress)" $FACTORY "factory address"
}

burn_token_deployer_nonce0() {
    [ "$(cast nonce $TOKEN_DEPLOYER --rpc-url $RH)" -ge 1 ] && return
    confirm "Robinhood: $TOKEN_DEPLOYER burns nonce 0 with a 0-value self-transfer"
    send $RH $TOKEN_DEPLOYER $TOKEN_DEPLOYER --value 0 >/dev/null
}

deploy_token() {
    if [ "$(code_size $TOKEN $RH)" -eq 0 ]; then
        need "$(cast nonce $TOKEN_DEPLOYER --rpc-url $RH)" 1 "token deployer nonce ($TOKEN is its nonce-1 address)"
        confirm "Robinhood: $TOKEN_DEPLOYER (nonce 1) deploys CyberToken -> $TOKEN (mints nothing)"
        need "$(send $RH $TOKEN_DEPLOYER --create "$(cat out/CyberToken.hex)" | jq -r .contractAddress)" $TOKEN "token address"
    fi
    check_token_fresh
}

deploy_controller() {
    if [ "$(code_size $CONTROLLER $RH)" -eq 0 ]; then
        confirm "Robinhood: $DEPLOYER deploys CyberTokenController via $FACTORY -> $CONTROLLER"
        send $RH $DEPLOYER $FACTORY 'deploy(bytes,bytes32)' "$(cat out/controller-initcode.hex)" "$SALT" >/dev/null
    fi
    need "$(cast call $CONTROLLER 'token()(address)' --rpc-url $RH)" $TOKEN "controller token()"
    need "$(cast call $CONTROLLER 'endpoint()(address)' --rpc-url $RH)" $RH_ENDPOINT "controller endpoint()"
    need "$(cast call $RH_ENDPOINT 'delegates(address)(address)' $CONTROLLER --rpc-url $RH)" $DELEGATE "controller delegate"
}

hand_token_to_controller() {
    local owner
    owner=$(cast call $TOKEN 'owner()(address)' --rpc-url $RH)
    if ! eq "$owner" $CONTROLLER; then
        need "$owner" $TOKEN_DEPLOYER "token owner"
        confirm "Robinhood: $TOKEN_DEPLOYER (nonce 2) hands token ownership to the controller $CONTROLLER"
        send $RH $TOKEN_DEPLOYER $TOKEN 'transferOwnership(address)' $CONTROLLER >/dev/null
    fi
    need "$(cast call $TOKEN 'owner()(address)' --rpc-url $RH)" $CONTROLLER "token owner"
}

# ensure_libs <rpc> <endpoint> <oapp> <eid> <send-lib> <recv-lib>  (delegate)
ensure_libs() {
    local rpc=$1 ep=$2 oapp=$3 eid=$4 sl=$5 rl=$6
    if ! eq "$(cast call $ep 'getSendLibrary(address,uint32)(address)' $oapp $eid --rpc-url $rpc)" $sl ||
        [ "$(cast call $ep 'isDefaultSendLibrary(address,uint32)(bool)' $oapp $eid --rpc-url $rpc)" = true ]; then
        confirm "eid $eid: pin send library $sl on $oapp"
        send $rpc $DELEGATE $ep 'setSendLibrary(address,uint32,address)' $oapp $eid $sl >/dev/null
    fi
    if ! receive_lib_pinned $rpc $ep $oapp $eid $rl; then
        confirm "eid $eid: pin receive library $rl on $oapp"
        send $rpc $DELEGATE $ep 'setReceiveLibrary(address,uint32,address,uint256)' $oapp $eid $rl 0 >/dev/null
    fi
}

receive_lib_pinned() {
    local r
    r=$(cast call $2 'getReceiveLibrary(address,uint32)(address,bool)' $3 $4 --rpc-url $1 | tr '\n' ' ')
    eq "$(awk '{print $1}' <<<"$r")" "$5" && [ "$(awk '{print $2}' <<<"$r")" = false ]
}

# ensure_uln <rpc> <endpoint> <oapp> <lib> <eid> <confirmations> <dvns-csv>  (delegate)
ensure_uln() {
    local rpc=$1 ep=$2 oapp=$3 lib=$4 eid=$5 want
    want=$(uln "$6" "$7")
    if ! eq "$(cast call $ep 'getConfig(address,address,uint32,uint32)(bytes)' $oapp $lib $eid 2 --rpc-url $rpc)" "$want"; then
        confirm "eid $eid: ULN on $lib = $6 confirmations, DVNs $7"
        send $rpc $DELEGATE $ep 'setConfig(address,address,(uint32,uint32,bytes)[])' $oapp $lib "[($eid,2,$want)]" >/dev/null
    fi
    need "$(cast call $ep 'getConfig(address,address,uint32,uint32)(bytes)' $oapp $lib $eid 2 --rpc-url $rpc)" "$want" "ULN $lib eid $eid"
}

# Owner actions on the Robinhood controller; the delegate key owns it until handover.
ensure_rh_owner_config() {
    if ! eq "$(cast call $CONTROLLER 'peers(uint32)(bytes32)' $ETH_EID --rpc-url $RH)" "$(b32 $ADAPTER)"; then
        confirm "Robinhood: controller.setPeer($ETH_EID, ETH adapter)"
        send $RH $DELEGATE $CONTROLLER 'setPeer(uint32,bytes32)' $ETH_EID "$(b32 $ADAPTER)" >/dev/null
    fi
    if ! eq "$(cast call $CONTROLLER 'enforcedOptions(uint32,uint16)(bytes)' $ETH_EID 1 --rpc-url $RH)" "$(opt $GAS_TO_ETH)"; then
        confirm "Robinhood: controller.setEnforcedOptions($ETH_EID, lzReceive $GAS_TO_ETH)"
        send $RH $DELEGATE $CONTROLLER 'setEnforcedOptions((uint32,uint16,bytes)[])' "[($ETH_EID,1,$(opt $GAS_TO_ETH))]" >/dev/null
    fi
}

deploy_robinhood() {
    need "$(cast chain-id --rpc-url $RH)" 4663 "Robinhood chain id"
    deploy_factory
    burn_token_deployer_nonce0
    deploy_token
    need "$(supply)" 0 "CYBER totalSupply after token deploy"
    deploy_controller
    hand_token_to_controller
    need "$(supply)" 0 "CYBER totalSupply after ownership handoff"
    ensure_libs $RH $RH_ENDPOINT $CONTROLLER $ETH_EID $RH_SEND_LIB $RH_RECV_LIB
    ensure_uln $RH $RH_ENDPOINT $CONTROLLER $RH_SEND_LIB $ETH_EID $RH_CONF "$(csv "${RH_DVNS[@]}")"
    ensure_uln $RH $RH_ENDPOINT $CONTROLLER $RH_RECV_LIB $ETH_EID $ETH_CONF "$(csv "${RH_DVNS[@]}")"
    ensure_rh_owner_config
    need "$(supply)" 0 "CYBER totalSupply after wiring"
    log "Robinhood side done"
}

wire_eth() {
    need "$(cast chain-id --rpc-url $ETH)" 1 "Ethereum chain id"
    need "$(cast call $ETH_ENDPOINT 'delegates(address)(address)' $ADAPTER --rpc-url $ETH)" $DELEGATE "ETH adapter delegate"
    ensure_libs $ETH $ETH_ENDPOINT $ADAPTER $RH_EID $ETH_SEND_LIB $ETH_RECV_LIB
    ensure_uln $ETH $ETH_ENDPOINT $ADAPTER $ETH_SEND_LIB $RH_EID $ETH_CONF "$(csv "${ETH_DVNS[@]}")"
    ensure_uln $ETH $ETH_ENDPOINT $ADAPTER $ETH_RECV_LIB $RH_EID $RH_CONF "$(csv "${ETH_DVNS[@]}")"
    log "Ethereum delegate config done; remaining: ETH Safe batch (./robinhood.sh safe-batch)"
}

safe_batch() {
    echo "Safe $ETH_SAFE (Ethereum), both txs to $ADAPTER, value 0:"
    echo "1) setPeer($RH_EID, $(b32 $CONTROLLER))"
    echo "   $(cast calldata 'setPeer(uint32,bytes32)' $RH_EID "$(b32 $CONTROLLER)")"
    echo "2) setEnforcedOptions([($RH_EID, 1, $(opt $GAS_TO_RH))])"
    echo "   $(cast calldata 'setEnforcedOptions((uint32,uint16,bytes)[])' "[($RH_EID,1,$(opt $GAS_TO_RH))]")"
}

check() {
    local peer owner
    need "$(cast code $FACTORY --rpc-url $RH)" "$(cat out/Create2Deployer.runtime.hex)" "factory runtime"
    check_token_fresh
    need "$(cast call $TOKEN 'owner()(address)' --rpc-url $RH)" $CONTROLLER "token owner"
    need "$(cast call $CONTROLLER 'token()(address)' --rpc-url $RH)" $TOKEN "controller token()"
    need "$(cast call $CONTROLLER 'endpoint()(address)' --rpc-url $RH)" $RH_ENDPOINT "controller endpoint()"
    need "$(cast call $RH_ENDPOINT 'delegates(address)(address)' $CONTROLLER --rpc-url $RH)" $DELEGATE "controller delegate"
    need "$(cast call $CONTROLLER 'peers(uint32)(bytes32)' $ETH_EID --rpc-url $RH)" "$(b32 $ADAPTER)" "Robinhood peer"
    need "$(cast call $CONTROLLER 'enforcedOptions(uint32,uint16)(bytes)' $ETH_EID 1 --rpc-url $RH)" "$(opt $GAS_TO_ETH)" "Robinhood enforced options"
    need "$(cast call $RH_ENDPOINT 'getConfig(address,address,uint32,uint32)(bytes)' $CONTROLLER $RH_SEND_LIB $ETH_EID 2 --rpc-url $RH)" "$(uln $RH_CONF "$(csv "${RH_DVNS[@]}")")" "Robinhood send ULN"
    need "$(cast call $RH_ENDPOINT 'getConfig(address,address,uint32,uint32)(bytes)' $CONTROLLER $RH_RECV_LIB $ETH_EID 2 --rpc-url $RH)" "$(uln $ETH_CONF "$(csv "${RH_DVNS[@]}")")" "Robinhood receive ULN"
    need "$(cast call $ETH_ENDPOINT 'getConfig(address,address,uint32,uint32)(bytes)' $ADAPTER $ETH_SEND_LIB $RH_EID 2 --rpc-url $ETH)" "$(uln $ETH_CONF "$(csv "${ETH_DVNS[@]}")")" "Ethereum send ULN"
    need "$(cast call $ETH_ENDPOINT 'getConfig(address,address,uint32,uint32)(bytes)' $ADAPTER $ETH_RECV_LIB $RH_EID 2 --rpc-url $ETH)" "$(uln $RH_CONF "$(csv "${ETH_DVNS[@]}")")" "Ethereum receive ULN"
    for side in "$RH $RH_ENDPOINT $CONTROLLER $ETH_EID $RH_SEND_LIB $RH_RECV_LIB" "$ETH $ETH_ENDPOINT $ADAPTER $RH_EID $ETH_SEND_LIB $ETH_RECV_LIB"; do
        read -r rpc ep oapp eid sl rl <<<"$side"
        need "$(cast call $ep 'getSendLibrary(address,uint32)(address)' $oapp $eid --rpc-url $rpc)" $sl "send library $oapp"
        need "$(cast call $ep 'isDefaultSendLibrary(address,uint32)(bool)' $oapp $eid --rpc-url $rpc)" false "send library pinned $oapp"
        receive_lib_pinned $rpc $ep $oapp $eid $rl || die "receive library not pinned to $rl on $oapp"
    done
    owner=$(cast call $CONTROLLER 'owner()(address)' --rpc-url $RH)
    peer=$(cast call $ADAPTER 'peers(uint32)(bytes32)' $RH_EID --rpc-url $ETH)
    log "controller owner: $owner"
    log "CYBER supply on Robinhood: $(supply)"
    if eq "$peer" "$(b32 $CONTROLLER)"; then
        need "$(cast call $ADAPTER 'enforcedOptions(uint32,uint16)(bytes)' $RH_EID 1 --rpc-url $ETH)" "$(opt $GAS_TO_RH)" "Ethereum enforced options"
        log "pathway OPEN (ETH Safe batch executed)"
    else
        need "$peer" 0x0000000000000000000000000000000000000000000000000000000000000000 "ETH adapter peer for $RH_EID"
        log "pathway CLOSED: ETH Safe batch not executed yet"
    fi
    log "check ok"
}

handover() {
    local safe=${1:?usage: handover <robinhood-safe>}
    [ "$(code_size "$safe" $RH)" -gt 0 ] || die "$safe has no code on Robinhood"
    log "Safe $safe: threshold $(cast call "$safe" 'getThreshold()(uint256)' --rpc-url $RH), owners $(cast call "$safe" 'getOwners()(address[])' --rpc-url $RH)"
    if ! eq "$(cast call $CONTROLLER 'owner()(address)' --rpc-url $RH)" "$safe"; then
        confirm "Robinhood: controller.transferOwnership($safe)"
        send $RH $DELEGATE $CONTROLLER 'transferOwnership(address)' "$safe" >/dev/null
    fi
    need "$(cast call $CONTROLLER 'owner()(address)' --rpc-url $RH)" "$safe" "controller owner"
    log "handover done"
}

verify() {
    local proxy=() id status
    [ -n "${HTTPS_PROXY:-}" ] && proxy=(--proxy "$HTTPS_PROXY")
    : "${ETHERSCAN_API_KEY:?set ETHERSCAN_API_KEY}"
    for c in "Create2Deployer $FACTORY src/deployer/Create2Deployer.sol v0.8.14+commit.80d49f37 -" \
        "CyberToken $TOKEN src/core/CyberToken.sol v0.8.14+commit.80d49f37 -" \
        "CyberTokenController $CONTROLLER src/CyberTokenController.sol v0.8.22+commit.4fc1097e $(cat out/controller-args.hex)"; do
        read -r name addr path compiler args <<<"$c"
        [ "$args" = - ] && args=
        id=$(curl -s "${proxy[@]}" --max-time 60 "https://api.etherscan.io/v2/api?chainid=4663" \
            --data-urlencode "apikey=$ETHERSCAN_API_KEY" --data-urlencode module=contract --data-urlencode action=verifysourcecode \
            --data-urlencode codeformat=solidity-standard-json-input --data-urlencode "sourceCode@sources/$name.json" \
            --data-urlencode "contractaddress=$addr" --data-urlencode "contractname=$path:$name" \
            --data-urlencode "compilerversion=$compiler" --data-urlencode "constructorArguements=$args" | jq -r .result)
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            sleep 6
            status=$(curl -s "${proxy[@]}" --max-time 60 "https://api.etherscan.io/v2/api?chainid=4663&module=contract&action=checkverifystatus&guid=$id&apikey=$ETHERSCAN_API_KEY" | jq -r .result)
            [ "$status" != "Pending in queue" ] && break
        done
        log "etherscan $name: $status"
        id=$(jq -n --slurpfile std "sources/$name.json" --arg v "${compiler#v}" --arg c "$path:$name" \
            '{stdJsonInput: $std[0], compilerVersion: $v, contractIdentifier: $c}' |
            curl -s --max-time 60 -H 'content-type: application/json' --data @- "https://sourcify.dev/server/v2/verify/4663/$addr" | jq -r '.verificationId // .customCode // .message')
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            sleep 6
            status=$(curl -s --max-time 60 "https://sourcify.dev/server/v2/verify/$id" | jq -r 'if .isJobCompleted then (.contract.match // .error.customCode // "done") else "pending" end')
            [ "$status" != pending ] && break
        done
        log "sourcify $name: $status (job $id)"
    done
}

# ---------------------------------------------------------------- simulation (local anvil forks, no keys)

FORK_PIDS=()
stop_forks() { [ ${#FORK_PIDS[@]} -gt 0 ] && kill "${FORK_PIDS[@]}" 2>/dev/null || true; }

start_fork() {
    anvil --fork-url "$1" --port "$2" --silent &
    FORK_PIDS+=($!)
    for _ in $(seq 60); do cast chain-id --rpc-url "http://127.0.0.1:$2" >/dev/null 2>&1 && return; sleep 1; done
    die "fork on :$2 did not start"
}

imp() { cast rpc anvil_impersonateAccount "$2" --rpc-url "$1" >/dev/null; }
as() { imp "$1" "$2" && cast rpc anvil_setBalance "$2" 0x56BC75E2D63100000 --rpc-url "$1" >/dev/null; }

reverts() { if cast call "$@" >/dev/null 2>&1; then die "expected revert: $*"; fi; }

# Read the PacketSent of a receipt into PKT_* (header, payload hash, guid, message, nonce).
packet_of() {
    local data
    data=$(jq -r --arg t "$(cast keccak 'PacketSent(bytes,bytes,address)')" '.logs[] | select(.topics[0]==$t) | .data' <<<"$1")
    local p
    p=$(cast abi-decode --input 'f(bytes,bytes,address)' "$data" | head -1)
    p=${p#0x}
    PKT_HEADER=0x${p:0:162}
    PKT_PAYLOAD_HASH=$(cast keccak "0x${p:162}")
    PKT_GUID=0x${p:162:64}
    PKT_MESSAGE=0x${p:226}
    PKT_NONCE=$((16#${p:2:16}))
    PKT_SENDER=0x${p:26:64}
}

# deliver <dst-rpc> <dst-endpoint> <recv-lib> <receiver> <src-eid> <confirmations> <lzReceive-gas> <dvn...>
# Every listed DVN attests, then lzReceive runs with exactly the enforced gas (what the executor forwards).
deliver() {
    local rpc=$1 ep=$2 rl=$3 recv=$4 src=$5 conf=$6 gas=$7 dvn data intrinsic
    shift 7
    for dvn in "$@"; do
        as $rpc $dvn
        send $rpc $dvn $rl 'verify(bytes,bytes32,uint64)' $PKT_HEADER $PKT_PAYLOAD_HASH $conf >/dev/null
    done
    send $rpc $TOKEN_DEPLOYER $rl 'commitVerification(bytes,bytes32)' $PKT_HEADER $PKT_PAYLOAD_HASH >/dev/null
    data=$(cast calldata 'lzReceive((uint32,bytes32,uint64),address,bytes32,bytes,bytes)' "($src,$PKT_SENDER,$PKT_NONCE)" $recv $PKT_GUID $PKT_MESSAGE 0x)
    intrinsic=$(python3 -c "b=bytes.fromhex('${data#0x}'); print(21000+sum(16 if x else 4 for x in b))")
    send $rpc $TOKEN_DEPLOYER --gas-limit $((intrinsic + gas)) $ep "$data" >/dev/null
}

# bridge <src-rpc> <src-oapp> <dst-eid> <from> <to> <amount>  -> receipt json
bridge() {
    local rpc=$1 oapp=$2 eid=$3 from=$4 to=$5 amount=$6 sp fee
    sp="($eid,$(b32 $to),$amount,$amount,0x,0x,0x)"
    fee=$(num "$(cast call $oapp 'quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)((uint256,uint256))' "$sp" false --rpc-url $rpc | tr -d '(),')")
    send $rpc $from --value $fee $oapp 'send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)' "$sp" "($fee,0)" $from
}

balance() { num "$(cast call "$1" 'balanceOf(address)(uint256)' "$2" --rpc-url "$3")"; }

gas_report() {
    local gp_rh gp_eth
    gp_rh=$(cast gas-price --rpc-url $RH_RPC)
    gp_eth=$(cast gas-price --rpc-url $ETH_RPC)
    echo
    log "gas needed (L2 gas from the forks + Arbitrum L1 data gas from NodeInterface, at current prices)"
    python3 - "$GASLOG" "$gp_rh" "$gp_eth" "$RH" "$RH_RPC" <<'PY'
import json, subprocess, sys
log, gp_rh, gp_eth, rh_fork, rh_rpc = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5]
cast = lambda *a: subprocess.run(["cast", *a], capture_output=True, text=True, check=True).stdout.strip()
tot = {}
for line in open(log):
    rpc, sender, h = line.split()
    rcpt = json.loads(cast("receipt", h, "--rpc-url", rpc, "--json"))
    gas = int(rcpt["gasUsed"], 16)
    chain = "robinhood" if rpc == rh_fork else "ethereum"
    if chain == "robinhood":
        tx = json.loads(cast("tx", h, "--rpc-url", rpc, "--json"))
        to = tx.get("to") or "0x" + "00" * 20
        l1 = cast("call", "0x00000000000000000000000000000000000000C8",
                  "gasEstimateL1Component(address,bool,bytes)(uint64,uint256,uint256)",
                  to, "true" if not tx.get("to") else "false", tx["input"], "--rpc-url", rh_rpc).split()[0]
        gas += int(l1)
    key = (chain, sender.lower())
    tot[key] = tot.get(key, 0) + gas
for (chain, sender), gas in sorted(tot.items()):
    wei = gas * (gp_rh if chain == "robinhood" else gp_eth)
    print(f"  {chain:9} {sender}  gas {gas:>9,}  ~{wei/1e18:.6f} ETH  (fund {wei*5/1e18:.6f} with 5x headroom)")
PY
}

simulate() {
    build
    trap stop_forks EXIT
    start_fork "$RH_RPC" 18547
    start_fork "$ETH_RPC" 18548
    MODE=sim
    RH=http://127.0.0.1:18547
    ETH=http://127.0.0.1:18548
    GASLOG=$(mktemp)
    # The deploy keys keep their real balances, so the run also proves the funding is enough.
    for a in $DEPLOYER $TOKEN_DEPLOYER $DELEGATE; do imp $RH $a; done
    for a in $DELEGATE $TOKEN_DEPLOYER; do imp $ETH $a; done
    as $ETH $ETH_SAFE

    log "[sim] deploy + wire Robinhood"
    deploy_robinhood
    log "[sim] no EOA can mint after the handoff"
    reverts --from $TOKEN_DEPLOYER $TOKEN 'mint(address,uint256)' $TOKEN_DEPLOYER 1 --rpc-url $RH
    reverts --from $DELEGATE $TOKEN 'mint(address,uint256)' $DELEGATE 1 --rpc-url $RH
    reverts --from $DEPLOYER $TOKEN 'mint(address,uint256)' $DEPLOYER 1 --rpc-url $RH
    log "[sim] re-running deploy is a no-op"
    deploy_robinhood >/dev/null
    log "[sim] Ethereum delegate config"
    wire_eth
    log "[sim] the delegate cannot do the Safe's part"
    reverts --from $DELEGATE $ADAPTER 'setPeer(uint32,bytes32)' $RH_EID "$(b32 $CONTROLLER)" --rpc-url $ETH
    local gas_deploy=$GASLOG
    GASLOG=
    log "[sim] ETH Safe batch (impersonated)"
    send $ETH $ETH_SAFE $ADAPTER "$(cast calldata 'setPeer(uint32,bytes32)' $RH_EID "$(b32 $CONTROLLER)")" >/dev/null
    send $ETH $ETH_SAFE $ADAPTER "$(cast calldata 'setEnforcedOptions((uint32,uint16,bytes)[])' "[($RH_EID,1,$(opt $GAS_TO_RH))]")" >/dev/null
    check

    local user=0x000000000000000000000000000000000000b0b5 amount=1000000000000000000 locked0 r
    as $RH $user
    log "[sim] worst case: the recipient has delegated votes on Robinhood"
    send $RH $user $TOKEN 'delegate(address)' $user >/dev/null
    locked0=$(balance $TOKEN $ADAPTER $ETH)
    send $ETH $TOKEN_DEPLOYER $TOKEN 'approve(address,uint256)' $ADAPTER $amount >/dev/null
    r=$(bridge $ETH $ADAPTER $RH_EID $TOKEN_DEPLOYER $user $amount)
    packet_of "$r"
    log "[sim] one DVN alone cannot commit"
    as $RH ${RH_DVNS[0]}
    send $RH ${RH_DVNS[0]} $RH_RECV_LIB 'verify(bytes,bytes32,uint64)' $PKT_HEADER $PKT_PAYLOAD_HASH $ETH_CONF >/dev/null
    reverts --from $TOKEN_DEPLOYER $RH_RECV_LIB 'commitVerification(bytes,bytes32)' $PKT_HEADER $PKT_PAYLOAD_HASH --rpc-url $RH
    log "[sim] ETH -> Robinhood delivered with exactly $GAS_TO_RH gas"
    deliver $RH $RH_ENDPOINT $RH_RECV_LIB $CONTROLLER $ETH_EID $ETH_CONF $GAS_TO_RH "${RH_DVNS[@]}"
    need "$(balance $TOKEN $user $RH)" $amount "Robinhood balance after bridge-in"
    need "$(supply)" $amount "Robinhood supply == bridged amount"
    need "$(balance $TOKEN $ADAPTER $ETH)" "$(python3 -c "print($locked0 + $amount)")" "ETH adapter locked after bridge-in"

    log "[sim] a packet whose sender is not the peer is rejected"
    local fake_header=${PKT_HEADER:0:28}000000000000000000000000000000000000000000000000000000000000dead${PKT_HEADER:92}
    for d in "${RH_DVNS[@]}"; do send $RH $d $RH_RECV_LIB 'verify(bytes,bytes32,uint64)' $fake_header $PKT_PAYLOAD_HASH $ETH_CONF >/dev/null; done
    reverts --from $TOKEN_DEPLOYER $RH_RECV_LIB 'commitVerification(bytes,bytes32)' $fake_header $PKT_PAYLOAD_HASH --rpc-url $RH

    log "[sim] Robinhood -> ETH delivered with exactly $GAS_TO_ETH gas"
    send $RH $user $TOKEN 'approve(address,uint256)' $CONTROLLER $amount >/dev/null
    r=$(bridge $RH $CONTROLLER $ETH_EID $user $user $amount)
    packet_of "$r"
    deliver $ETH $ETH_ENDPOINT $ETH_RECV_LIB $ADAPTER $RH_EID $RH_CONF $GAS_TO_ETH "${ETH_DVNS[@]}"
    need "$(supply)" 0 "Robinhood supply after bridge-out"
    need "$(balance $TOKEN $user $ETH)" $amount "ETH balance after bridge-out"
    need "$(balance $TOKEN $ADAPTER $ETH)" $locked0 "ETH adapter locked after round trip"

    log "[sim] handover to a stand-in owner; the delegate key loses owner rights"
    send $RH $DELEGATE $CONTROLLER 'transferOwnership(address)' 0x000000000000000000000000000000000000Cafe >/dev/null
    reverts --from $DELEGATE $CONTROLLER 'setPeer(uint32,bytes32)' $ETH_EID "$(b32 $ADAPTER)" --rpc-url $RH

    GASLOG=$gas_deploy
    gas_report
    log "simulation passed"
}

case ${1:-} in
build) build ;;
simulate) simulate ;;
deploy)
    build
    for a in $DEPLOYER $TOKEN_DEPLOYER $DELEGATE; do check_key $a; done
    deploy_robinhood
    ;;
wire-eth)
    build
    check_key $DELEGATE
    wire_eth
    ;;
safe-batch) safe_batch ;;
check) build >/dev/null && check ;;
handover)
    check_key $DELEGATE
    handover "${2:-}"
    ;;
verify) build >/dev/null && verify ;;
*) sed -n '2,4p' "$0" && echo "usage: $0 build|simulate|deploy|wire-eth|safe-batch|check|handover <safe>|verify" && exit 1 ;;
esac
