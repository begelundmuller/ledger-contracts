# Financial contracts on the Ethereum ledger

### Getting started

Initialize a new, "blank" chain with the custom genesis file:

```
mkdir ./chain
geth --datadir ./chain/ init genesis.json
```

Launch the console:

```
geth --dev --rpc --rpcaddr="0.0.0.0" --rpccorsdomain="*" --rpcapi="admin,db,eth,debug,miner,net,shh,txpool,personal,web3" --targetgaslimit 1000000000000 --datadir ./chain console
```

Create three accounts:

```
> personal.newAccount("123456")
"[Account 1]"
> personal.newAccount("123456")
"[Account 2]"
> personal.newAccount("123456")
"[Account 3]"
```

Mine some Ether:

```
> miner.start()
// Wait for a few blocks to be mined
> miner.stop()
```

Transfer some of the mined Ether to the other accounts:

```
> eth.sendTransaction({from: eth.accounts[0], to: eth.accounts[1], value: web3.toWei(10, "ether")})
```

Check balance of each account:

```
> web3.fromWei(eth.getBalance(eth.accounts[i]))
```

Set the console to mine only when there are unmined transactions:

```
> loadScript('./mine.js')
```

If you would like to interact directly with the console, you might want to launch a new console in a new window (to avoid being interrupted by mining logs):

```
geth --dev attach ipc:./chain/geth.ipc
```

Now compile the Solidity contracts (must have `solc` installed):

```
bash ./recompile.sh
```

Create some tokens and a feed:

```
node bootstrap.js
```

Now you can create and test the sample portfolio with

```
node portfolio.js
```
