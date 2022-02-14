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

# ---- Rinkeby ----

# ---- Mainnet ----

# deploy
dapp create src/TimeLock.sol:TimeLock --verify

# verify
export ETHERSCAN_API_KEY=...
TIME_LOCK=
dapp verify-contract src/TimeLock.sol:TimeLock $TIME_LOCK

# flatten
hevm flatten --source-file src/TimeLock.sol > tmp/flat.sol
```
