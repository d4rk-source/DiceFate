import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import {
  mainnet,
  polygon,
  optimism,
  arbitrum,
  base,
  localhost,
} from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'DiceFate',
  projectId: '0x595e61847f1e9f8a0b3e5c5e8d5e6e7e',
  chains: [localhost, mainnet, polygon, optimism, arbitrum, base],
  ssr: true,
});

// Update this with your deployed contract address
export const DICE_FATE_CONTRACT = "0xf426ad4b99d4e8077ad6f55625c6e695354fe5c3";

export const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || 'http://127.0.0.1:8545';

export function setContractAddress(address: string) {
  if (typeof window !== 'undefined') {
    localStorage.setItem('DICE_FATE_CONTRACT', address);
  }
}
