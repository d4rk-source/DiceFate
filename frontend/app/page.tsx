"use client";

import { useState, useEffect } from "react";
import { useAccount, useBalance } from "wagmi";
import { useDiceFate } from "@/lib/hooks";
import WalletConnect from "@/components/WalletConnect";
import BettingForm from "@/components/BettingForm";
import BetHistory from "@/components/BetHistory";
import ContractInfo from "@/components/ContractInfo";

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

  const [contractAddress, setContractAddress] = useState<string>("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Get contract address from environment or localStorage
    const addr = localStorage.getItem("DICE_FATE_CONTRACT");
    if (addr) {
      setContractAddress(addr);
    }
    setLoading(false);
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-dice-dark">
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-dice-dark via-purple-900 to-dice-dark py-12 px-4">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="gradient-text text-5xl font-bold mb-2">🎲 DiceFate</h1>
          <p className="text-gray-400 text-lg">
            Provably fair dice betting with Chainlink VRF
          </p>
        </div>

        {/* Wallet Connect */}
        <div className="mb-8 flex justify-center">
          <WalletConnect />
        </div>

        {!isConnected ? (
          <div className="card text-center py-12">
            <p className="text-gray-400 text-lg mb-4">
              Connect your wallet to get started
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
            {/* Main Betting Panel */}
            <div className="lg:col-span-2">
              <BettingForm onPlaceBet={placeBet} isLoading={isWritePending} />
            </div>

            {/* Sidebar Info */}
            <div className="space-y-6">
              <ContractInfo
                userBalance={balance?.formatted || "0"}
                contractBalance={contractBalance}
                contractAddress={contractAddress}
              />
            </div>
          </div>
        )}

        {/* Bet History */}
        {isConnected && (
          <div>
            <BetHistory
              bets={playerBets as any}
              isLoading={isPlayerBetsLoading}
              contractAddress={contractAddress}
            />
          </div>
        )}
      </div>
    </div>
  );
}
