curr=$(pwd)/..
solc -o $curr/contracts --bin --abi $curr/contracts/CurrencyToken.sol
solc -o $curr/contracts --bin --abi $curr/contracts/ContractManager.sol
solc -o $curr/contracts --bin --abi $curr/contracts/SimpleFeed.sol
solc -o $curr/contracts --bin --abi $curr/contracts/DecisionFeed.sol
solc -o $curr/contracts --bin --abi $curr/contracts/CurrencyToken.sol
