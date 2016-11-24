Remove any files existing in the chain folder:

  rm -r ./chain

Initialize a new, "blank" chain with the custom genesis file:

  geth --datadir ./chain/ init genesis.json

Launch the chain

  geth --dev --rpc --rpcaddr="0.0.0.0" --rpccorsdomain="*" --rpcapi="admin,db,eth,debug,miner,net,shh,txpool,personal,web3" --targetgaslimit 1000000000000 --datadir ./chain --mine console

Create three accounts

  > personal.newAccount("123456")
  "[Account 1]"
  > personal.newAccount("123456")
  "[Account 2]"
  > personal.newAccount("123456")
  "[Account 3]"

Mine some ether and transfer to other accounts:

  eth.sendTransaction({from: eth.accounts[0], to: eth.accounts[1], value: web3.toWei(10, "ether")})

Check balance of each account

  web3.fromWei(eth.getBalance(eth.accounts[i]))

Now, launch a new console in a separate window (to avoid the interruption of mining logs)

  geth --dev attach ipc:./chain/geth.ipc

Use this console for your tests. In the host terminal, you will likely want to say miner.start(), so that blocks incited in the development window get mined.












// Thing that can go wrong:
// - Insufficient funds
// - Observable not available

// Also
// - Type checking
// - Checking time

If one party defaults, should other still transfer?

IfBefore not supported
