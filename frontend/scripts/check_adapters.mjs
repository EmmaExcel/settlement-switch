import { createPublicClient, http } from 'viem';
import { sepolia } from 'viem/chains';

// Config
const RPC_URL = 'https://ethereum-sepolia-rpc.publicnode.com';
const CONTRACT_ADDRESS = '0xc16a01431b1d980b0df125df4d8df4633c4d5ba0';
const DEST_CHAIN_ID = 421614; // Arbitrum Sepolia

// Minimal ABI definitions
const ABI = [
  {
    type: 'function',
    name: 'getBridgeAdapters',
    inputs: [{ name: 'chainId', type: 'uint256' }],
    outputs: [{ name: 'adapters', type: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getBridgeAdapter',
    inputs: [{ name: 'chainId', type: 'uint256' }],
    outputs: [{ name: 'adapter', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'isChainSupported',
    inputs: [{ name: 'chainId', type: 'uint256' }],
    outputs: [{ name: 'isSupported', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'isTokenSupported',
    inputs: [{ name: 'token', type: 'address' }],
    outputs: [{ name: 'isSupported', type: 'bool' }],
    stateMutability: 'view',
  },
];

// USDC on Sepolia
const USDC = '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238';

async function main() {
  const client = createPublicClient({
    chain: sepolia,
    transport: http(RPC_URL),
  });

  console.log('RPC:', RPC_URL);
  console.log('Contract:', CONTRACT_ADDRESS);
  console.log('Dest Chain:', DEST_CHAIN_ID);

  // Basic connectivity
  const blockNumber = await client.getBlockNumber();
  console.log('Block:', blockNumber);

  // Check token support
  const tokenSupported = await client.readContract({
    address: CONTRACT_ADDRESS,
    abi: ABI,
    functionName: 'isTokenSupported',
    args: [USDC],
  });
  console.log('USDC supported:', tokenSupported);

  // Check chain support
  const chainSupported = await client.readContract({
    address: CONTRACT_ADDRESS,
    abi: ABI,
    functionName: 'isChainSupported',
    args: [BigInt(DEST_CHAIN_ID)],
  });
  console.log(`Chain ${DEST_CHAIN_ID} supported:`, chainSupported);

  // Fetch adapters with legacy fallback
  let adaptersOut = [];
  try {
    const adapters = await client.readContract({
      address: CONTRACT_ADDRESS,
      abi: ABI,
      functionName: 'getBridgeAdapters',
      args: [BigInt(DEST_CHAIN_ID)],
    });
    adaptersOut = adapters;
    console.log(`Adapters for ${DEST_CHAIN_ID} (array):`, adaptersOut);
  } catch (e) {
    try {
      const single = await client.readContract({
        address: CONTRACT_ADDRESS,
        abi: ABI,
        functionName: 'getBridgeAdapter',
        args: [BigInt(DEST_CHAIN_ID)],
      });
      const isZero = single === '0x0000000000000000000000000000000000000000';
      adaptersOut = isZero ? [] : [single];
      console.log(`Adapters for ${DEST_CHAIN_ID} (legacy single):`, adaptersOut);
    } catch (e2) {
      console.log(`Adapters for ${DEST_CHAIN_ID}: <unavailable>`);
    }
  }
}

main().catch((err) => {
  console.error('Adapter check failed:', err?.message || err);
  process.exit(1);
});