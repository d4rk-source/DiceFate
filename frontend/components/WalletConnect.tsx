"use client";

import { useState } from "react";
import { useAccount, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { LOCAL_CHAIN_ID, RPC_URL, isSupportedChain } from "../lib/config";

function shortenAddress(address: string) {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export default function WalletConnect() {
  const { address, chainId, isConnected } = useAccount();
  const { connect, connectors, isPending: isConnecting } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();
  const [networkError, setNetworkError] = useState<string>("");

  const injectedConnector =
    connectors.find((connector) => connector.id === "injected") ??
    connectors[0];
  const isWrongNetwork = isConnected && !isSupportedChain(chainId);

  const handleSwitchNetwork = async () => {
    setNetworkError("");
    try {
      await switchChain?.({ chainId: LOCAL_CHAIN_ID });
    } catch {
      setNetworkError(
        "Automatic switch failed. Use Add/Switch Localhost to force-add chain 31337 in your wallet.",
      );
    }
  };

  const handleAddOrSwitchLocalhost = async () => {
    setNetworkError("");
    try {
      const ethereum = (
        window as Window & {
          ethereum?: {
            request: (args: {
              method: string;
              params?: unknown[];
            }) => Promise<unknown>;
          };
        }
      ).ethereum;
      if (!ethereum) {
        setNetworkError(
          "No injected wallet found. Please open this page in your wallet-enabled browser.",
        );
        return;
      }

      await ethereum.request({
        method: "wallet_addEthereumChain",
        params: [
          {
            chainId: "0x7a69",
            chainName: "Localhost 8545",
            nativeCurrency: {
              name: "ETH",
              symbol: "ETH",
              decimals: 18,
            },
            rpcUrls: [RPC_URL],
          },
        ],
      });
    } catch {
      setNetworkError(
        "Wallet rejected network change. Please set chain ID 31337 manually in your wallet network settings.",
      );
    }
  };

  return (
    <div className="flex flex-col items-center gap-3">
      {isConnected ? (
        <div className="flex flex-col sm:flex-row items-center gap-3">
          <div className="card py-3 px-4 text-sm text-gray-300">
            {shortenAddress(address ?? "")}
            {isWrongNetwork ? " · Wrong network" : " · Connected"}
            {chainId ? ` · Chain ${chainId}` : ""}
          </div>
          {isWrongNetwork ? (
            <>
              <button
                type="button"
                onClick={handleSwitchNetwork}
                disabled={isSwitching}
                className="btn-primary px-5 py-2"
              >
                {isSwitching ? "Switching..." : "Switch to Localhost"}
              </button>
              <button
                type="button"
                onClick={handleAddOrSwitchLocalhost}
                className="bg-blue-900 hover:bg-blue-800 text-white px-5 py-2 rounded-lg border border-blue-500"
              >
                Add/Switch Localhost
              </button>
            </>
          ) : null}
          <button
            type="button"
            onClick={() => disconnect()}
            className="bg-gray-800 hover:bg-gray-700 text-white px-5 py-2 rounded-lg border border-gray-600"
          >
            Disconnect
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={() =>
            injectedConnector && connect({ connector: injectedConnector })
          }
          disabled={!injectedConnector || isConnecting}
          className="btn-primary px-6 py-3"
        >
          {isConnecting
            ? "Connecting..."
            : injectedConnector
              ? "Connect Wallet"
              : "Install a wallet"}
        </button>
      )}
      {isWrongNetwork && (
        <div className="text-yellow-300 text-sm text-center max-w-xl">
          Expected chain ID: {LOCAL_CHAIN_ID}. Detected: {chainId ?? "unknown"}.
        </div>
      )}
      {networkError && (
        <div className="text-red-300 text-sm text-center max-w-xl">
          {networkError}
        </div>
      )}
    </div>
  );
}
