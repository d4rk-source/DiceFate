"use client";

import { useState, useEffect } from "react";
import { useAccount, useBalance } from "wagmi";
import { useDiceFate } from "../lib/hooks";
import WalletConnect from "../components/WalletConnect";
import BettingForm from "../components/BettingForm";
import BetHistory from "../components/BetHistory";
import ContractInfo from "../components/ContractInfo";
import { DICE_FATE_CONTRACT } from "../lib/config";

export default function Home() {
  const { address, isConnected } = useAccount();
  const { data: balance } = useBalance({ address });
  const {
    placeBet,
    contractBalance,
    playerBets,
    isPlayerBetsLoading,
    isWritePending,
  } = useDiceFate();

  const [contractAddress, setContractAddress] = useState<string>(DICE_FATE_CONTRACT);

  useEffect(() => {
    const stored = localStorage.getItem("DICE_FATE_CONTRACT");
    if (stored) setContractAddress(stored);
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-dice-dark via-purple-900 to-dice-dark py-12 px-4">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-12">
          <h1 className="gradient-text text-5xl font-bold mb-2">DiceFate</h1>
          <p className="text-gray-400 text-lg">
            Provably fair on-chain dice · Chainlink VRF · Variable payouts
          </p>
          <p className="text-gray-600 text-xs mt-2">
            Home lab project — local Anvil deployment
          </p>
        </div>

        <div className="mb-8 flex justify-center">
          <WalletConnect />
        </div>

        {!isConnected ? (
          <div className="card text-center py-12">
            <p className="text-gray-400 text-lg mb-4">Connect your wallet to get started</p>
            <p className="text-gray-500 text-sm">Requires Anvil running on localhost:8545</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
            <div className="lg:col-span-2">
              <BettingForm onPlaceBet={placeBet} isLoading={isWritePending} />
            </div>
            <div className="space-y-6">
              <ContractInfo
                userBalance={balance?.formatted ?? "0"}
                contractBalance={contractBalance}
                contractAddress={contractAddress}
              />
            </div>
          </div>
        )}

        {isConnected && (
          <BetHistory
            bets={playerBets}
            isLoading={isPlayerBetsLoading}
            contractAddress={contractAddress}
          />
        )}
      </div>
    </div>
  );
}
