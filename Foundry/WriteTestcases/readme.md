create test cases for smart contracts using foundry

- forge build
- forge test
- forge test -vvvv
- forge test --match-path test/HelloWorld.t.sol
- forge test --match-path test/HelloWorld.t.sol --gas-report

In foundry.toml file 
- solc_version = "0.8.17"
- optimizer = true
- optimizer_runs = 200


import libraries 
- forge install rari-capital/solmate =>  if this error then 
- forge install rari-capital/solmate --no-commit
- forge remappings
- forge update lib/solmate
- forge remove solmate


- forge install OpenZeppelin/openzeppelin-contracts --no-commit

Formatter
- forge fmt


console (Counter, test, log int)
- forge test --match-path test/Console.t.sol -vv















