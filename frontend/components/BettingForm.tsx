"use client";

import { useState } from "react";
import { useAccount } from "wagmi";

interface BettingFormProps {
  onPlaceBet: (targetNumber: number, ethAmount: string) => Promise<string>;
  isLoading: boolean;
}

export default function BettingForm({
  onPlaceBet,
  isLoading,
}: BettingFormProps) {
  const { isConnected } = useAccount();
  const [targetNumber, setTargetNumber] = useState<number>(50);
  const [betAmount, setBetAmount] = useState<string>("0.1");
  const [error, setError] = useState<string>("");
  const [success, setSuccess] = useState<string>("");

  const handlePlaceBet = async () => {
    try {
      setError("");
      setSuccess("");

      if (!isConnected) {
        setError("Please connect your wallet");
        return;
      }

      if (targetNumber < 2 || targetNumber > 100) {
        setError("Target number must be between 2 and 100");
        return;
      }

      if (parseFloat(betAmount) <= 0) {
        setError("Bet amount must be greater than 0");
        return;
      }

      const hash = await onPlaceBet(targetNumber, betAmount);
      setSuccess(`Bet placed! Transaction: ${hash.slice(0, 10)}...`);
      setBetAmount("0.1");
      setTargetNumber(50);

      setTimeout(() => setSuccess(""), 5000);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to place bet");
    }
  };

  const probabilityPercentage = Math.round((targetNumber / 100) * 100);

  // Variable payout calculation: multiplier = 100 / targetNumber
  const payoutMultiplier = (100 / targetNumber) * 0.95; // Apply 5% house edge
  const basePayout = parseFloat(betAmount) * (100 / targetNumber);
  const finalPayout = basePayout * 0.95; // After 5% house edge

  // Expected value calculation
  const winProbability = (targetNumber - 1) / 100;
  const lossProbability = 1 - winProbability;
  const expectedValue =
    finalPayout * winProbability - parseFloat(betAmount) * lossProbability;

  return (
    <div className="card">
      <h2 className="text-2xl font-bold mb-6">Place Your Bet</h2>

      <div className="space-y-6">
        {/* Target Number Selector */}
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            Roll Under:{" "}
            <span className="text-dice-purple text-2xl font-bold">
              {targetNumber}
            </span>
            <span className="text-xs font-normal text-gray-500 ml-2">
              (
              {targetNumber <= 33
                ? "🔥 High Risk/Reward"
                : targetNumber <= 66
                  ? "⚖️ Balanced"
                  : "🛡️ Low Risk"}
              )
            </span>
          </label>
          <input
            type="range"
            min="2"
            max="100"
            value={targetNumber}
            onChange={(e) => setTargetNumber(parseInt(e.target.value))}
            className="w-full h-2 bg-dice-dark border border-dice-purple rounded-lg appearance-none cursor-pointer"
            disabled={isLoading}
          />
          <div className="flex justify-between text-xs text-gray-400 mt-2">
            <span>High Risk (2)</span>
            <span>Low Risk (100)</span>
          </div>
        </div>

        {/* Probability Display */}
        <div className="bg-dice-dark bg-opacity-50 rounded-lg p-4">
          <div className="flex justify-between items-center mb-4">
            <span className="text-gray-400">Win Probability:</span>
            <span className="text-dice-purple font-bold text-lg">
              {probabilityPercentage}%
            </span>
          </div>
          <div className="w-full bg-gray-700 rounded-full h-2">
            <div
              className="bg-gradient-to-r from-dice-purple to-pink-500 h-2 rounded-full"
              style={{ width: `${probabilityPercentage}%` }}
            />
          </div>
        </div>

        {/* Bet Amount */}
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            Bet Amount (ETH)
          </label>
          <input
            type="number"
            value={betAmount}
            onChange={(e) => setBetAmount(e.target.value)}
            placeholder="0.1"
            step="0.01"
            min="0"
            className="input-field w-full"
            disabled={isLoading}
          />
        </div>

        {/* Payout Calculation */}
        <div className="bg-dice-dark bg-opacity-50 rounded-lg p-4 space-y-2">
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">Bet Amount:</span>
            <span>{betAmount} ETH</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">Risk Multiplier:</span>
            <span className="text-orange-400 font-bold">
              {(100 / targetNumber).toFixed(2)}x
            </span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">After 5% Fee:</span>
            <span>{payoutMultiplier.toFixed(3)}x</span>
          </div>
          <div className="border-t border-gray-600 pt-2 flex justify-between">
            <span className="text-gray-300 font-medium">If Win (Payout):</span>
            <span className="text-green-400 font-bold">
              {finalPayout.toFixed(6)} ETH
            </span>
          </div>
          <div className="flex justify-between text-xs text-gray-500 pt-1">
            <span>Expected Value:</span>
            <span
              className={expectedValue >= 0 ? "text-green-500" : "text-red-500"}
            >
              {expectedValue >= 0 ? "+" : ""}
              {expectedValue.toFixed(6)} ETH (
              {((expectedValue / parseFloat(betAmount)) * 100).toFixed(1)}%)
            </span>
          </div>
        </div>

        {/* Risk/Reward Info */}
        <div className="bg-blue-900 bg-opacity-20 border border-blue-500 rounded-lg p-3 text-xs text-blue-200">
          <div className="font-semibold mb-2">📊 Variable Payout System:</div>
          <div>• Lower target = Higher payout but lower win chance</div>
          <div>• Higher target = Lower payout but higher win chance</div>
          <div>• Multiplier = 100 ÷ Target Number (then -5% fee)</div>
        </div>

        {/* Place Bet Button */}
        <button
          onClick={handlePlaceBet}
          disabled={isLoading || !isConnected}
          className="btn-primary w-full text-lg font-bold py-3"
        >
          {isLoading ? (
            <span className="flex items-center justify-center gap-2">
              <div className="spinner border-2 border-white"></div>
              Placing Bet...
            </span>
          ) : (
            "🎲 Place Bet"
          )}
        </button>

        {/* Error Message */}
        {error && (
          <div className="bg-red-500 bg-opacity-20 border border-red-500 rounded-lg p-4 text-red-200">
            {error}
          </div>
        )}

        {/* Success Message */}
        {success && (
          <div className="bg-green-500 bg-opacity-20 border border-green-500 rounded-lg p-4 text-green-200">
            {success}
          </div>
        )}

        {/* Disclaimer */}
        <p className="text-xs text-gray-500 text-center">
          This is a demo contract. Only works with Anvil local deployment.
        </p>
      </div>
    </div>
  );
}
