import { createConfig, http } from "wagmi";
import { injected } from "wagmi";
import { defineChain } from "viem";

export const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || 'http://127.0.0.1:8545';

// Anvil uses chain ID 31337. wagmi's built-in `localhost` is 1337 (Hardhat), so we define our own.
const anvil = defineChain({
  id: 31337,
  name: "Anvil",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [RPC_URL] } },
});

export const LOCAL_CHAIN_ID = anvil.id;

export function isSupportedChain(chainId?: number) {
  return chainId === LOCAL_CHAIN_ID;
}

export const config = createConfig({
  chains: [anvil],
  connectors: [injected({ shimDisconnect: true })],
  transports: {
    [anvil.id]: http(RPC_URL),
  },
  ssr: true,
});

// Update this with your deployed contract address
export const DICE_FATE_CONTRACT = "0x5fc8d32690cc91d4c39d9d3abcbd16989f875707";

export function setContractAddress(address: string) {
  if (typeof window !== 'undefined') {
    localStorage.setItem('DICE_FATE_CONTRACT', address);
  }
}
