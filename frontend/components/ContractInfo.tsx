"use client";

import { formatEther } from "viem";

interface ContractInfoProps {
  userBalance: string;
  contractBalance: any;
  contractAddress: string;
}

export default function ContractInfo({
  userBalance,
  contractBalance,
  contractAddress,
}: ContractInfoProps) {
  const formattedContractBalance = contractBalance
    ? formatEther(contractBalance as bigint)
    : "0";

  return (
    <div className="space-y-4">
      {/* User Balance */}
      <div className="card">
        <h3 className="text-lg font-semibold mb-2 text-gray-300">
          Your Balance
        </h3>
        <p className="text-3xl font-bold gradient-text">
          {parseFloat(userBalance).toFixed(4)} ETH
        </p>
      </div>

      {/* House Balance */}
      <div className="card">
        <h3 className="text-lg font-semibold mb-2 text-gray-300">
          House Balance
        </h3>
        <p className="text-3xl font-bold text-green-400">
          {parseFloat(formattedContractBalance).toFixed(4)} ETH
        </p>
        <p className="text-xs text-gray-500 mt-2">Available for payouts</p>
      </div>

      {/* Game Info */}
      <div className="card">
        <h3 className="text-lg font-semibold mb-3 text-gray-300">Game Rules</h3>
        <ul className="space-y-2 text-sm text-gray-400">
          <li>✓ Roll 1-100 dice</li>
          <li>✓ Win if roll &lt; target</li>
          <li>✓ Payout: 1.95x - 5%</li>
          <li>✓ Chainlink VRF</li>
        </ul>
      </div>

      {/* Contract Address */}
      {contractAddress && (
        <div className="card">
          <h3 className="text-lg font-semibold mb-2 text-gray-300">Contract</h3>
          <p className="text-xs font-mono text-gray-500 break-all">
            {contractAddress}
          </p>
        </div>
      )}
    </div>
  );
}
