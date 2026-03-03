"use client";

import { useReadContract } from "wagmi";
import { formatEther } from "viem";
import { DICE_FATE_ABI } from "@/lib/abi";

interface BetHistoryProps {
  bets: number[];
  isLoading: boolean;
  contractAddress: string;
}

interface BetDetails {
  player: string;
  amount: bigint;
  targetNumber: number;
  rollResult: bigint;
  resolved: boolean;
  won: boolean;
}

export default function BetHistory({
  bets,
  isLoading,
  contractAddress,
}: BetHistoryProps) {
  const placeholderBets = bets || [];

  return (
    <div className="card">
      <h2 className="text-2xl font-bold mb-6">Your Bet History</h2>

      {isLoading ? (
        <div className="flex justify-center py-8">
          <div className="spinner"></div>
        </div>
      ) : placeholderBets.length === 0 ? (
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
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">
                  Bet ID
                </th>
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">
                  Amount
                </th>
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">
                  Target
                </th>
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">
                  Result
                </th>
                <th className="text-left px-4 py-3 text-gray-400 font-semibold">
                  Status
                </th>
              </tr>
            </thead>
            <tbody>
              {placeholderBets.map((betId, idx) => (
                <BetRow
                  key={betId}
                  betId={betId}
                  contractAddress={contractAddress}
                  index={idx}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}

      <p className="text-xs text-gray-500 mt-4">
        Note: View specific bet details by looking at contract events or
        querying individual bet data.
      </p>
    </div>
  );
}

function BetRow({
  betId,
  contractAddress,
  index,
}: {
  betId: number;
  contractAddress: string;
  index: number;
}) {
  const { data: betDetails } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: DICE_FATE_ABI as any,
    functionName: "getBet",
    args: [BigInt(betId)],
    query: { enabled: !!contractAddress },
  }) as { data: BetDetails | undefined };

  if (!betDetails) {
    return null;
  }

  return (
    <tr className="border-b border-gray-700 hover:bg-dice-dark bg-opacity-30 transition">
      <td className="px-4 py-3">#{betId}</td>
      <td className="px-4 py-3">{formatEther(betDetails.amount)} ETH</td>
      <td className="px-4 py-3">
        <span className="text-dice-purple font-semibold">
          &lt; {betDetails.targetNumber}
        </span>
      </td>
      <td className="px-4 py-3">
        {betDetails.resolved ? (
          <span className="font-semibold">{Number(betDetails.rollResult)}</span>
        ) : (
          <span className="text-gray-500">-</span>
        )}
      </td>
      <td className="px-4 py-3">
        {!betDetails.resolved ? (
          <span className="inline-block px-3 py-1 rounded-full text-xs font-semibold bg-yellow-500 bg-opacity-20 text-yellow-300">
            Pending
          </span>
        ) : betDetails.won ? (
          <span className="inline-block px-3 py-1 rounded-full text-xs font-semibold bg-green-500 bg-opacity-20 text-green-300">
            Won ✓
          </span>
        ) : (
          <span className="inline-block px-3 py-1 rounded-full text-xs font-semibold bg-red-500 bg-opacity-20 text-red-300">
            Lost ✗
          </span>
        )}
      </td>
    </tr>
  );
}
