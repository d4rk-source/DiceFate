"use client";

import { formatEther } from "viem";

interface ContractInfoProps {
  userBalance: string;
  contractBalance: bigint | undefined;
  contractAddress: string;
}

export default function ContractInfo({
  userBalance,
  contractBalance,
  contractAddress,
}: ContractInfoProps) {
  const formattedBalance = contractBalance != null
    ? parseFloat(formatEther(contractBalance)).toFixed(4)
    : "0";

  return (
    <div className="space-y-4">
      <div className="card">
        <h3 className="text-lg font-semibold mb-2 text-gray-300">Your Balance</h3>
        <p className="text-3xl font-bold gradient-text">
          {parseFloat(userBalance).toFixed(4)} ETH
        </p>
      </div>

      <div className="card">
        <h3 className="text-lg font-semibold mb-2 text-gray-300">House Liquidity</h3>
        <p className="text-3xl font-bold text-green-400">{formattedBalance} ETH</p>
        <p className="text-xs text-gray-500 mt-2">Available to cover payouts</p>
      </div>

      <div className="card">
        <h3 className="text-lg font-semibold mb-3 text-gray-300">Game Rules</h3>
        <ul className="space-y-2 text-sm text-gray-400">
          <li>✓ Roll is 1–100 (uniform)</li>
          <li>✓ Win if roll &lt; your target</li>
          <li>✓ Multiplier = 100 ÷ (target − 1)</li>
          <li>✓ House edge: 5% on all targets</li>
          <li>✓ Randomness: Chainlink VRF</li>
        </ul>
      </div>

      {contractAddress && (
        <div className="card">
          <h3 className="text-lg font-semibold mb-2 text-gray-300">Contract</h3>
          <p className="text-xs font-mono text-gray-500 break-all">{contractAddress}</p>
        </div>
      )}
    </div>
  );
}
