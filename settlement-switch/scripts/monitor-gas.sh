#!/bin/bash

# Gas Price Monitor for Optimal Deployment Timing
# Usage: ./monitor-gas.sh [target_gwei]

TARGET_GWEI=${1:-50}  # Default target: 50 gwei
MAINNET_RPC_URL=$(grep MAINNET_RPC_URL .env | cut -d '=' -f2)

echo "🔍 Monitoring gas prices for deployment..."
echo "📊 Target: ${TARGET_GWEI} gwei or lower"
echo "⏰ Checking every 30 seconds..."
echo ""

while true; do
    # Get current gas price
    GAS_WEI=$(cast gas-price --rpc-url $MAINNET_RPC_URL 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Convert wei to gwei
        GAS_GWEI=$(echo "scale=2; $GAS_WEI / 1000000000" | bc)
        
        # Get current time
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Check if gas price is below target
        if (( $(echo "$GAS_GWEI <= $TARGET_GWEI" | bc -l) )); then
            echo "🎯 [$TIMESTAMP] DEPLOY NOW! Gas: ${GAS_GWEI} gwei (Target: ${TARGET_GWEI})"
            
            # Calculate deployment cost
            ESTIMATED_GAS=16679633
            COST_ETH=$(echo "scale=6; $GAS_WEI * $ESTIMATED_GAS / 1000000000000000000" | bc)
            COST_USD=$(echo "scale=2; $COST_ETH * 3000" | bc)
            
            echo "💰 Estimated cost: ${COST_ETH} ETH (~$${COST_USD} USD)"
            echo ""
            echo "🚀 Run deployment command:"
            echo "forge script script/SimpleDeploy.s.sol:SimpleDeploy --rpc-url \$MAINNET_RPC_URL --private-key \$PRIVATE_KEY --broadcast --verify"
            break
        else
            echo "⏳ [$TIMESTAMP] Gas: ${GAS_GWEI} gwei (waiting for ≤${TARGET_GWEI})"
        fi
    else
        echo "❌ [$TIMESTAMP] Failed to fetch gas price"
    fi
    
    sleep 30
done