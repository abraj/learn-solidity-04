# -include .env
# include .env
include /Users/abraj/dev/archive/learn-solidity/env/.env

.PHONY: test deploy

build:; forge clean && forge build

install:
	@forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit
	@forge install github.com/transmissions11/solmate@v6 --no-commit
	@forge install Cyfrin/foundry-devops@0.2.3 --no-commit

deploy:
	@forge script script/Raffle.s.sol:DeployRaffle --rpc-url $(RPC_URL) --broadcast --sender $(SENDER1) --account $(ACCOUNT1) --password-file $(PWD_FILE1) -vvvv

deploy-sepolia:
	@forge script script/Raffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --broadcast --account $(ACCOUNT3) --password-file $(PWD_FILE3) --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
