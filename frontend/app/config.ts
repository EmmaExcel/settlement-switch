import { createConfig, http } from 'wagmi'
import { mainnet, sepolia, arbitrumSepolia, arbitrum } from 'wagmi/chains'
import { CHAIN_CONFIG } from '@/lib/addresses'

export const config = createConfig({
  // Include mainnet and Arbitrum One for production bridging
  chains: [sepolia, arbitrumSepolia, mainnet, arbitrum],
  ssr: true,
  transports: {
    [sepolia.id]: http(CHAIN_CONFIG.sepolia.rpcUrls.public.http[0]),
    [arbitrumSepolia.id]: http(CHAIN_CONFIG.arbitrumSepolia.rpcUrls.public.http[0]),
    [mainnet.id]: http(CHAIN_CONFIG.mainnet.rpcUrls.public.http[0]),
    [arbitrum.id]: http(CHAIN_CONFIG.arbitrumOne.rpcUrls.public.http[0]),
  },
})
