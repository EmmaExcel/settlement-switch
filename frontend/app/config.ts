import { createConfig, http } from 'wagmi'
import { mainnet, sepolia, arbitrumSepolia } from 'wagmi/chains'
import { CHAIN_CONFIG } from '@/lib/addresses'

export const config = createConfig({
  // Put Sepolia first so the default public client points to Sepolia.
  chains: [sepolia, arbitrumSepolia, mainnet],
  ssr: true,
  transports: {
    [sepolia.id]: http(CHAIN_CONFIG.sepolia.rpcUrls.public.http[0]),
    [arbitrumSepolia.id]: http(CHAIN_CONFIG.arbitrumSepolia.rpcUrls.public.http[0]),
    [mainnet.id]: http(),
  },
})