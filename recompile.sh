curr=$(pwd)
solc -o $curr/contracts --bin --abi $curr/contracts/CurrencyToken.sol
solc -o $curr/contracts --bin --abi $curr/contracts/ContractManager.sol
