curr=$(pwd)
solc -o $curr/source --bin --abi $curr/source/CurrencyToken.sol
solc -o $curr/source --bin --abi $curr/source/ContractEngine.sol
