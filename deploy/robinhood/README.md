# CYBER on Robinhood Chain

Deploys CYBER on Robinhood Chain (chainId 4663, LayerZero eid 30416) and opens a single pathway,
Robinhood ↔ Ethereum. The pathway is configured like Base ↔ Ethereum: the LayerZero Labs and Nethermind DVNs
are both required, and LayerZero's default executor delivers.

| Contract | Robinhood address | Deployed by |
|---|---|---|
| Create2Deployer | `0x8eD1282a1aCE084De1E99E9Ce5ed68896C49d65f` | `0x0e0b…66BD`, nonce 0 (same address as on every EVM chain) |
| CyberToken | `0x14778860E937f509e651192a90589dE711Fb88a9` | `0xE906…06cD`, nonce 1 (same address as on every EVM chain; mints nothing) |
| CyberTokenController | `0x3cBfDaDA8abCb43A42eAEd1B88e72B06eb2523da` | CREATE2 via the factory, salt `keccak256("Cyber")` |

`sources/` holds the Basescan-verified standard-JSON inputs of the Base deployment. `build` compiles them with
the original solc versions. It then checks that the output is byte-identical to Base's creation code. That
check is what makes every contract here verifiable with those same inputs. The controller lands on a different
address than `0x9A9D…` because its constructor takes the endpoint, and Robinhood's EndpointV2 is not `0x1a44…`.
The factory runs the cybertoken repo's Create2Deployer, Base's verified `0x9B20…`. That is functionally
identical to the unverified `0x8eD1…` code on the other chains, so it can be verified.

## Run order

```bash
./robinhood.sh simulate     # full rehearsal on local forks; prints the gas each key needs
DEPLOYER_PK=… TOKEN_DEPLOYER_PK=… DELEGATE_PK=… ./robinhood.sh deploy   # Robinhood side
DELEGATE_PK=… ./robinhood.sh wire-eth      # Ethereum: the delegate pins libraries + ULN for eid 30416
ETHERSCAN_API_KEY=… HTTPS_PROXY=… ./robinhood.sh verify   # robin.etherscan.io + Sourcify (Blockscout reads Sourcify)
./robinhood.sh safe-batch   # calldata for the ETH treasury Safe (setPeer + setEnforcedOptions); executing it opens the pathway
DELEGATE_PK=… ./robinhood.sh handover <robinhood-safe>   # before the Safe batch executes
./robinhood.sh check        # read-only check of both chains
```

Hand the controller to the Robinhood Safe before the ETH Safe batch executes. Once the pathway is open, whoever
owns the controller can repoint its peer, so that power must not sit with a hot key.

`runs/` records every live transaction, including the first round trip. Its Ethereum → Robinhood leg carried an
executor native drop, so the test wallet had gas on Robinhood without a separate transfer.

Every step checks on-chain state before it sends, so a re-run skips finished work. Live sends ask for
confirmation unless `YES=1` is set. `simulate` needs `anvil` and solc 0.8.14 and 0.8.22 in `~/.svm`.

Funding `0xE906…06cD` on Robinhood must be a plain transfer into it. Its nonce 0, 1 and 2 must stay unused
until `deploy` sends them: nonce 0 is the burn, nonce 1 is the token, nonce 2 is the ownership handoff.
