#!/bin/bash

# Contract Interaction Script
# This script allows you to interact with deployed contracts directly using cast commands

# ============ Configuration ============
SEPOLIA_RPC="https://eth-sepolia.g.alchemy.com/v2/demo"  # Using Alchemy demo endpoint
ARBITRUM_SEPOLIA_RPC="https://sepolia-rollup.arbitrum.io/rpc"

# Deployed Contract Addresses
STABLECOIN_SWITCH="0xc16a01431b1d980b0df125df4d8df4633c4d5ba0"  # Sepolia
ARBITRUM_INBOX="0xaae29b0366299461418f5324a79afc425be5ae21"      # Sepolia

# Your wallet private key (set this as environment variable for security)
# export PRIVATE_KEY="your_private_key_here"

# ============ Helper Functions ============

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}============ $1 ============${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if private key is set
check_private_key() {
    if [ -z "$PRIVATE_KEY" ]; then
        print_error "PRIVATE_KEY environment variable not set"
        echo "Please set your private key: export PRIVATE_KEY=\"your_private_key_here\""
        exit 1
    fi
}

# ============ StablecoinSwitch Interactions ============

# Get contract owner
get_owner() {
    print_header "Getting Contract Owner"
    cast call $STABLECOIN_SWITCH "owner()" --rpc-url $SEPOLIA_RPC
}

# Check if a token is supported
check_token_support() {
    if [ -z "$1" ]; then
        print_error "Please provide token address"
        echo "Usage: $0 check_token <token_address>"
        exit 1
    fi
    
    print_header "Checking Token Support for $1"
    cast call $STABLECOIN_SWITCH "isTokenSupported(address)" $1 --rpc-url $SEPOLIA_RPC
}

# Get supported tokens (this would need to be implemented if there's a getter)
get_supported_tokens() {
    print_header "Getting Supported Tokens"
    echo "Note: You'll need to check individual token addresses using check_token_support"
    echo "Known supported tokens from deployment:"
    echo "- 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
    echo "- 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6" 
    echo "- 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06"
}

# Add token support (owner only)
add_token_support() {
    check_private_key
    if [ -z "$1" ]; then
        print_error "Please provide token address"
        echo "Usage: $0 add_token <token_address>"
        exit 1
    fi
    
    print_header "Adding Token Support for $1"
    cast send $STABLECOIN_SWITCH "setTokenSupport(address,bool)" $1 true \
        --private-key $PRIVATE_KEY \
        --rpc-url $SEPOLIA_RPC \
        --gas-limit 100000
}

# Remove token support (owner only)
remove_token_support() {
    check_private_key
    if [ -z "$1" ]; then
        print_error "Please provide token address"
        echo "Usage: $0 remove_token <token_address>"
        exit 1
    fi
    
    print_header "Removing Token Support for $1"
    cast send $STABLECOIN_SWITCH "setTokenSupport(address,bool)" $1 false \
        --private-key $PRIVATE_KEY \
        --rpc-url $SEPOLIA_RPC \
        --gas-limit 100000
}

# Perform a token swap
swap_tokens() {
    check_private_key
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        print_error "Please provide all required parameters"
        echo "Usage: $0 swap <from_token> <to_token> <amount>"
        exit 1
    fi
    
    print_header "Swapping $3 tokens from $1 to $2"
    cast send $STABLECOIN_SWITCH "swapTokens(address,address,uint256)" $1 $2 $3 \
        --private-key $PRIVATE_KEY \
        --rpc-url $SEPOLIA_RPC \
        --gas-limit 200000
}

# ============ General Utilities ============

# Get ETH balance
get_eth_balance() {
    if [ -z "$1" ]; then
        print_error "Please provide address"
        echo "Usage: $0 balance <address>"
        exit 1
    fi
    
    print_header "Getting ETH Balance for $1"
    cast balance $1 --rpc-url $SEPOLIA_RPC --ether
}

# Get token balance
get_token_balance() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        print_error "Please provide token address and wallet address"
        echo "Usage: $0 token_balance <token_address> <wallet_address>"
        exit 1
    fi
    
    print_header "Getting Token Balance"
    cast call $1 "balanceOf(address)" $2 --rpc-url $SEPOLIA_RPC
}

# ============ Main Script Logic ============

case "$1" in
    "owner")
        get_owner
        ;;
    "check_token")
        check_token_support $2
        ;;
    "supported_tokens")
        get_supported_tokens
        ;;
    "add_token")
        add_token_support $2
        ;;
    "remove_token")
        remove_token_support $2
        ;;
    "swap")
        swap_tokens $2 $3 $4
        ;;
    "balance")
        get_eth_balance $2
        ;;
    "token_balance")
        get_token_balance $2 $3
        ;;
    "help"|"")
        print_header "Contract Interaction Commands"
        echo ""
        echo "Configuration Commands:"
        echo "  owner                           - Get contract owner"
        echo "  supported_tokens               - List known supported tokens"
        echo ""
        echo "Token Management Commands:"
        echo "  check_token <token_address>    - Check if token is supported"
        echo "  add_token <token_address>      - Add token support (owner only)"
        echo "  remove_token <token_address>   - Remove token support (owner only)"
        echo ""
        echo "Trading Commands:"
        echo "  swap <from_token> <to_token> <amount> - Swap tokens"
        echo ""
        echo "Utility Commands:"
        echo "  balance <address>              - Get ETH balance"
        echo "  token_balance <token> <wallet> - Get token balance"
        echo ""
        echo "Setup:"
        echo "  1. Set your RPC URL in the script (replace YOUR_INFURA_KEY)"
        echo "  2. Export your private key: export PRIVATE_KEY=\"your_key\""
        echo "  3. Make script executable: chmod +x interact.sh"
        echo ""
        echo "Examples:"
        echo "  ./interact.sh owner"
        echo "  ./interact.sh check_token 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
        echo "  ./interact.sh balance 0x253eF0749119119f228a362f8F74A35C0A273fA5"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use './interact.sh help' to see available commands"
        exit 1
        ;;
esac