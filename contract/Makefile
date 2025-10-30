# Arbitrum Foundry Template Makefile
# Common commands for Arbitrum development

# Load environment variables
include .env
export

# Default target
.DEFAULT_GOAL := help

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[0;37m
RESET := \033[0m

# ================================
# HELP
# ================================

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)Arbitrum Foundry Template$(RESET)"
	@echo "$(YELLOW)Available commands:$(RESET)"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ================================
# SETUP & INSTALLATION
# ================================

.PHONY: install
install: ## Install dependencies and set up the project
	@echo "$(BLUE)Installing Foundry dependencies...$(RESET)"
	forge install
	@echo "$(GREEN)Dependencies installed successfully!$(RESET)"

.PHONY: setup
setup: install ## Complete project setup (install + build + test)
	@echo "$(BLUE)Setting up Arbitrum Foundry Template...$(RESET)"
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Creating .env file from template...$(RESET)"; \
		cp .env.example .env; \
		echo "$(RED)⚠️  Please edit .env with your actual values!$(RESET)"; \
	fi
	$(MAKE) build
	$(MAKE) test
	@echo "$(GREEN)✅ Setup complete!$(RESET)"

# ================================
# BUILD & COMPILE
# ================================

.PHONY: build
build: ## Build the project
	@echo "$(BLUE)Building contracts...$(RESET)"
	forge build
	@echo "$(GREEN)Build completed!$(RESET)"

.PHONY: clean
clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(RESET)"
	forge clean
	rm -rf cache/ out/
	@echo "$(GREEN)Clean completed!$(RESET)"

.PHONY: rebuild
rebuild: clean build ## Clean and rebuild the project

# ================================
# TESTING
# ================================

.PHONY: test
test: ## Run all tests
	@echo "$(BLUE)Running tests...$(RESET)"
	forge test -vv

.PHONY: test-verbose
test-verbose: ## Run tests with verbose output
	@echo "$(BLUE)Running tests with verbose output...$(RESET)"
	forge test -vvvv

.PHONY: test-gas
test-gas: ## Run tests with gas reporting
	@echo "$(BLUE)Running tests with gas reporting...$(RESET)"
	forge test --gas-report

.PHONY: test-coverage
test-coverage: ## Generate test coverage report
	@echo "$(BLUE)Generating coverage report...$(RESET)"
	forge coverage
	forge coverage --report lcov

.PHONY: test-fork
test-fork: ## Run fork tests against Arbitrum
	@echo "$(BLUE)Running fork tests against Arbitrum...$(RESET)"
	forge test --fork-url $(ARBITRUM_RPC_URL) -vv

.PHONY: test-fork-sepolia
test-fork-sepolia: ## Run fork tests against Arbitrum Sepolia
	@echo "$(BLUE)Running fork tests against Arbitrum Sepolia...$(RESET)"
	forge test --fork-url $(ARBITRUM_SEPOLIA_RPC_URL) -vv

.PHONY: test-token
test-token: ## Run ArbitrumToken tests only
	@echo "$(BLUE)Running ArbitrumToken tests...$(RESET)"
	forge test --match-path test/ArbitrumToken.t.sol -vv

.PHONY: test-nft
test-nft: ## Run ArbitrumNFT tests only
	@echo "$(BLUE)Running ArbitrumNFT tests...$(RESET)"
	forge test --match-path test/ArbitrumNFT.t.sol -vv

.PHONY: test-staking
test-staking: ## Run ArbitrumStaking tests only
	@echo "$(BLUE)Running ArbitrumStaking tests...$(RESET)"
	forge test --match-path test/ArbitrumStaking.t.sol -vv

# ================================
# DEPLOYMENT
# ================================

.PHONY: deploy-sepolia
deploy-sepolia: ## Deploy to Arbitrum Sepolia testnet
	@echo "$(BLUE)Deploying to Arbitrum Sepolia...$(RESET)"
	@if [ -z "$(PRIVATE_KEY)" ]; then \
		echo "$(RED)Error: PRIVATE_KEY not set in .env$(RESET)"; \
		exit 1; \
	fi
	forge script script/DeployArbitrum.s.sol:DeployArbitrum \
		--rpc-url arbitrum-sepolia \
		--broadcast \
		--verify \
		--etherscan-api-key $(ARBITRUM_API_KEY) \
		-vvvv
	@echo "$(GREEN)✅ Deployment to Arbitrum Sepolia completed!$(RESET)"

.PHONY: deploy-mainnet
deploy-mainnet: ## Deploy to Arbitrum One mainnet
	@echo "$(RED)⚠️  DEPLOYING TO MAINNET - This will cost real ETH!$(RESET)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or wait 10 seconds to continue...$(RESET)"
	@sleep 10
	@echo "$(BLUE)Deploying to Arbitrum One...$(RESET)"
	@if [ -z "$(PRIVATE_KEY)" ]; then \
		echo "$(RED)Error: PRIVATE_KEY not set in .env$(RESET)"; \
		exit 1; \
	fi
	forge script script/DeployArbitrum.s.sol:DeployArbitrum \
		--rpc-url arbitrum \
		--broadcast \
		--verify \
		--etherscan-api-key $(ARBITRUM_API_KEY) \
		-vvvv
	@echo "$(GREEN)✅ Deployment to Arbitrum One completed!$(RESET)"

.PHONY: deploy-local
deploy-local: ## Deploy to local Anvil network
	@echo "$(BLUE)Deploying to local Anvil...$(RESET)"
	forge script script/DeployArbitrum.s.sol:DeployArbitrum \
		--rpc-url anvil \
		--broadcast \
		-vvvv
	@echo "$(GREEN)✅ Local deployment completed!$(RESET)"

.PHONY: simulate-sepolia
simulate-sepolia: ## Simulate deployment to Arbitrum Sepolia (dry run)
	@echo "$(BLUE)Simulating deployment to Arbitrum Sepolia...$(RESET)"
	forge script script/DeployArbitrum.s.sol:DeployArbitrum \
		--rpc-url arbitrum-sepolia \
		-vvvv

.PHONY: simulate-mainnet
simulate-mainnet: ## Simulate deployment to Arbitrum One (dry run)
	@echo "$(BLUE)Simulating deployment to Arbitrum One...$(RESET)"
	forge script script/DeployArbitrum.s.sol:DeployArbitrum \
		--rpc-url arbitrum \
		-vvvv

# ================================
# CONTRACT VERIFICATION
# ================================

.PHONY: verify-token
verify-token: ## Verify ArbitrumToken contract (requires CONTRACT_ADDRESS)
	@if [ -z "$(CONTRACT_ADDRESS)" ]; then \
		echo "$(RED)Error: CONTRACT_ADDRESS not provided$(RESET)"; \
		echo "$(YELLOW)Usage: make verify-token CONTRACT_ADDRESS=0x...$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Verifying ArbitrumToken at $(CONTRACT_ADDRESS)...$(RESET)"
	forge verify-contract $(CONTRACT_ADDRESS) ArbitrumToken \
		--chain-id 42161 \
		--etherscan-api-key $(ARBITRUM_API_KEY)

.PHONY: verify-nft
verify-nft: ## Verify ArbitrumNFT contract (requires CONTRACT_ADDRESS)
	@if [ -z "$(CONTRACT_ADDRESS)" ]; then \
		echo "$(RED)Error: CONTRACT_ADDRESS not provided$(RESET)"; \
		echo "$(YELLOW)Usage: make verify-nft CONTRACT_ADDRESS=0x...$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Verifying ArbitrumNFT at $(CONTRACT_ADDRESS)...$(RESET)"
	forge verify-contract $(CONTRACT_ADDRESS) ArbitrumNFT \
		--chain-id 42161 \
		--etherscan-api-key $(ARBITRUM_API_KEY)

.PHONY: verify-staking
verify-staking: ## Verify ArbitrumStaking contract (requires CONTRACT_ADDRESS)
	@if [ -z "$(CONTRACT_ADDRESS)" ]; then \
		echo "$(RED)Error: CONTRACT_ADDRESS not provided$(RESET)"; \
		echo "$(YELLOW)Usage: make verify-staking CONTRACT_ADDRESS=0x...$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Verifying ArbitrumStaking at $(CONTRACT_ADDRESS)...$(RESET)"
	forge verify-contract $(CONTRACT_ADDRESS) ArbitrumStaking \
		--chain-id 42161 \
		--etherscan-api-key $(ARBITRUM_API_KEY)

# ================================
# DEVELOPMENT TOOLS
# ================================

.PHONY: format
format: ## Format Solidity code
	@echo "$(BLUE)Formatting code...$(RESET)"
	forge fmt

.PHONY: lint
lint: ## Run linting checks
	@echo "$(BLUE)Running linting checks...$(RESET)"
	forge fmt --check

.PHONY: snapshot
snapshot: ## Generate gas snapshots
	@echo "$(BLUE)Generating gas snapshots...$(RESET)"
	forge snapshot

.PHONY: update
update: ## Update dependencies
	@echo "$(BLUE)Updating dependencies...$(RESET)"
	forge update

.PHONY: anvil
anvil: ## Start local Anvil node
	@echo "$(BLUE)Starting Anvil local node...$(RESET)"
	anvil --host 0.0.0.0 --port 8545

.PHONY: anvil-fork
anvil-fork: ## Start Anvil forked from Arbitrum One
	@echo "$(BLUE)Starting Anvil forked from Arbitrum One...$(RESET)"
	anvil --fork-url $(ARBITRUM_RPC_URL) --host 0.0.0.0 --port 8545

.PHONY: anvil-fork-sepolia
anvil-fork-sepolia: ## Start Anvil forked from Arbitrum Sepolia
	@echo "$(BLUE)Starting Anvil forked from Arbitrum Sepolia...$(RESET)"
	anvil --fork-url $(ARBITRUM_SEPOLIA_RPC_URL) --host 0.0.0.0 --port 8545

# ================================
# SECURITY & ANALYSIS
# ================================

.PHONY: slither
slither: ## Run Slither static analysis (requires slither installation)
	@echo "$(BLUE)Running Slither analysis...$(RESET)"
	@if command -v slither >/dev/null 2>&1; then \
		slither .; \
	else \
		echo "$(RED)Slither not installed. Install with: pip install slither-analyzer$(RESET)"; \
	fi

.PHONY: mythril
mythril: ## Run Mythril security analysis (requires mythril installation)
	@echo "$(BLUE)Running Mythril analysis...$(RESET)"
	@if command -v myth >/dev/null 2>&1; then \
		myth analyze src/ArbitrumToken.sol --solc-json mythril.json; \
	else \
		echo "$(RED)Mythril not installed. Install with: pip install mythril$(RESET)"; \
	fi

# ================================
# UTILITIES
# ================================

.PHONY: check-env
check-env: ## Check if environment variables are set
	@echo "$(BLUE)Checking environment variables...$(RESET)"
	@if [ -z "$(ARBITRUM_RPC_URL)" ]; then echo "$(RED)❌ ARBITRUM_RPC_URL not set$(RESET)"; else echo "$(GREEN)✅ ARBITRUM_RPC_URL set$(RESET)"; fi
	@if [ -z "$(ARBITRUM_SEPOLIA_RPC_URL)" ]; then echo "$(RED)❌ ARBITRUM_SEPOLIA_RPC_URL not set$(RESET)"; else echo "$(GREEN)✅ ARBITRUM_SEPOLIA_RPC_URL set$(RESET)"; fi
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "$(RED)❌ PRIVATE_KEY not set$(RESET)"; else echo "$(GREEN)✅ PRIVATE_KEY set$(RESET)"; fi
	@if [ -z "$(ARBITRUM_API_KEY)" ]; then echo "$(YELLOW)⚠️  ARBITRUM_API_KEY not set (verification will fail)$(RESET)"; else echo "$(GREEN)✅ ARBITRUM_API_KEY set$(RESET)"; fi

.PHONY: gas-price
gas-price: ## Check current gas prices on Arbitrum
	@echo "$(BLUE)Checking Arbitrum gas prices...$(RESET)"
	@cast gas-price --rpc-url $(ARBITRUM_RPC_URL)

.PHONY: balance
balance: ## Check ETH balance (requires ADDRESS)
	@if [ -z "$(ADDRESS)" ]; then \
		echo "$(RED)Error: ADDRESS not provided$(RESET)"; \
		echo "$(YELLOW)Usage: make balance ADDRESS=0x...$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Checking balance for $(ADDRESS)...$(RESET)"
	@cast balance $(ADDRESS) --rpc-url $(ARBITRUM_RPC_URL)

.PHONY: nonce
nonce: ## Check nonce for address (requires ADDRESS)
	@if [ -z "$(ADDRESS)" ]; then \
		echo "$(RED)Error: ADDRESS not provided$(RESET)"; \
		echo "$(YELLOW)Usage: make nonce ADDRESS=0x...$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Checking nonce for $(ADDRESS)...$(RESET)"
	@cast nonce $(ADDRESS) --rpc-url $(ARBITRUM_RPC_URL)

# ================================
# CI/CD TARGETS
# ================================

.PHONY: ci
ci: ## Run CI pipeline (build, test, coverage)
	@echo "$(BLUE)Running CI pipeline...$(RESET)"
	$(MAKE) build
	$(MAKE) test
	$(MAKE) test-coverage
	$(MAKE) lint
	@echo "$(GREEN)✅ CI pipeline completed successfully!$(RESET)"

.PHONY: pre-commit
pre-commit: ## Run pre-commit checks
	@echo "$(BLUE)Running pre-commit checks...$(RESET)"
	$(MAKE) format
	$(MAKE) lint
	$(MAKE) test
	@echo "$(GREEN)✅ Pre-commit checks passed!$(RESET)"

# ================================
# DOCUMENTATION
# ================================

.PHONY: docs
docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(RESET)"
	forge doc

.PHONY: tree
tree: ## Show project structure
	@echo "$(BLUE)Project structure:$(RESET)"
	@tree -I 'node_modules|cache|out|lib' -a

# ================================
# ALIASES
# ================================

.PHONY: t
t: test ## Alias for test

.PHONY: b
b: build ## Alias for build

.PHONY: d
d: deploy-sepolia ## Alias for deploy-sepolia

.PHONY: f
f: format ## Alias for format