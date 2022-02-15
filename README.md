# time-lock

```shell
npm i

# config .sethrc
cp .sethrc.copy .sethrc

# list accounts
ethsign ls

# import account
ethsign import

# delete imported key
rm $HOME/.ethereum/keystore/my-key

# lint
npm run lint

# solhint
npm run solhint

# compile
dapp build
# test
dapp test -v

# deploy
export ETHERSCAN_API_KEY=...

# 2 weeks
DELAY=1209600
dapp create src/TimeLock.sol:TimeLock $DELAY --verify

# verify
TIME_LOCK=
dapp verify-contract src/TimeLock.sol:TimeLock $TIME_LOCK $DELAY

# flatten
hevm flatten --source-file src/TimeLock.sol > tmp/flat.sol

# ---- Rinkeby ----
0x4402A7C8829489705852e54Da50Ebec60C8C86a8

# ---- Mainnet ----
0x0df9220aEaA28cE8bA06ADd7c5B3Cc6e7C1Cd511
```
