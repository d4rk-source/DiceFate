"use client";

import { useReadContract, useWriteContract, useChainId } from "wagmi";
import { formatEther } from "viem";
import { useState } from "react";
import { DICE_FATE_ABI } from "../lib/abi";

interface BetHistoryProps {
  bets: bigint[];
  isLoading: boolean;
  contractAddress: string;
}

interface BetDetails {
  player: `0x${string}`;
  amount: bigint;
  targetNumber: number;
  requestId: bigint;
  rollResult: bigint;
  resolved: boolean;
  won: boolean;
}

// Mirrors calculateWinPayout() from the Solidity contract using integer (BigInt) math
// so the displayed payout is always byte-for-byte identical to what the contract pays.
function calcWinPayout(amount: bigint, targetNumber: number): bigint {
  const BASIS_POINTS   = 10_000n;
  const DICE_RANGE     = 100n;
  const HOUSE_EDGE_BPS = 500n;
  const multiplier = (DICE_RANGE * BASIS_POINTS) / BigInt(targetNumber - 1);
  const gross      = (amount * multiplier) / BASIS_POINTS;
  return (gross * (BASIS_POINTS - HOUSE_EDGE_BPS)) / BASIS_POINTS;
}

export default function BetHistory({
  bets,
  isLoading,
  contractAddress,
}: BetHistoryProps) {
  const betList = bets ?? [];

  return (
    <div className="card">
      <h2 className="text-2xl font-bold mb-6">Your Bet History</h2>

      {isLoading ? (
        <div className="flex justify-center py-8">
          <div className="spinner"></div>
        </div>
      ) : betList.length === 0 ? (
        <div className="bg-dice-dark bg-opacity-50 rounded-lg p-8 text-center">
          <p className="text-gray-400 text-lg">No bets placed yet</p>
          <p className="text-gray-500 text-sm mt-2">
            Scroll up and place your first bet!
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-700">
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">ID</th>
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">Bet</th>
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">Target</th>
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">Roll</th>
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">Payout</th>
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">Status</th>
              </tr>
            </thead>
            <tbody>
              {betList.map((betId) => (
                <BetRow
                  key={betId.toString()}
                  betId={betId}
                  contractAddress={contractAddress}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function BetRow({
  betId,
  contractAddress,
}: {
  betId: bigint;
  contractAddress: string;
}) {
  const chainId = useChainId();
  const isLocal = chainId === 31337;

  const { data: bet, refetch } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: DICE_FATE_ABI,
    functionName: "getBet",
    args: [betId],
    query: { enabled: !!contractAddress },
  }) as { data: BetDetails | undefined; refetch: () => void };

  const { writeContractAsync } = useWriteContract();
  const [isResolving, setIsResolving] = useState(false);
  const [resolveError, setResolveError] = useState<string | null>(null);

  const simulateVRF = async () => {
    setIsResolving(true);
    setResolveError(null);
    try {
      await writeContractAsync({
        address: contractAddress as `0x${string}`,
        abi: DICE_FATE_ABI,
        functionName: "rollDice",
        args: [betId],
      });
      await refetch();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      setResolveError(msg.includes("Unauthorized") ? "Must be your bet" : "Transaction failed");
    } finally {
      setIsResolving(false);
    }
  };

  if (!bet) return null;

  const payout = bet.won ? calcWinPayout(bet.amount, bet.targetNumber) : 0n;

  return (
    <tr className="border-b border-gray-700 hover:bg-dice-dark bg-opacity-30 transition">
      <td className="px-4 py-3 text-gray-400">#{betId.toString()}</td>
      <td className="px-4 py-3">{formatEther(bet.amount)} ETH</td>
      <td className="px-4 py-3">
        <span className="text-dice-purple font-semibold">&lt; {bet.targetNumber}</span>
      </td>
      <td className="px-4 py-3">
        {bet.resolved ? (
          <span className="font-semibold">{Number(bet.rollResult)}</span>
        ) : (
          <span className="text-gray-500 italic">pending</span>
        )}
      </td>
      <td className="px-4 py-3">
        {!bet.resolved ? (
          <span className="text-gray-500">—</span>
        ) : bet.won ? (
          <span className="text-green-400 font-semibold">+{formatEther(payout)} ETH</span>
        ) : (
          <span className="text-red-400">—</span>
        )}
      </td>
      <td className="px-4 py-3">
        {!bet.resolved ? (
          <div className="flex flex-col gap-1">
            {isLocal ? (
              <>
                <button
                  onClick={simulateVRF}
                  disabled={isResolving}
                  className="px-3 py-1 rounded-full text-xs font-semibold bg-dice-purple bg-opacity-30 text-dice-purple hover:bg-opacity-50 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isResolving ? "Rolling..." : "Roll Dice"}
                </button>
                {resolveError && (
                  <span className="text-red-400 text-xs">{resolveError}</span>
                )}
              </>
            ) : (
              <span className="inline-block px-3 py-1 rounded-full text-xs font-semibold bg-yellow-500 bg-opacity-20 text-yellow-300">
                Pending VRF
              </span>
            )}
          </div>
        ) : bet.won ? (
          <span className="inline-block px-3 py-1 rounded-full text-xs font-semibold bg-green-500 bg-opacity-20 text-green-300">
            Won
          </span>
        ) : (
          <span className="inline-block px-3 py-1 rounded-full text-xs font-semibold bg-red-500 bg-opacity-20 text-red-300">
            Lost
          </span>
        )}
      </td>
    </tr>
  );
}
