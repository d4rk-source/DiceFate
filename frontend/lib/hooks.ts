import { useAccount, useWriteContract, useReadContract } from "wagmi";
import { parseEther } from "viem";
import { DICE_FATE_ABI } from "./abi";
import { DICE_FATE_CONTRACT } from "./config";

export function useDiceFate(contractAddress: string = DICE_FATE_CONTRACT) {
  const { address } = useAccount();

  const {
    writeContractAsync,
    isPending: isWritePending,
    error: writeError,
  } = useWriteContract();

  const { data: contractBalance, isLoading: isBalanceLoading } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: DICE_FATE_ABI,
    functionName: "contractBalance",
  });

  const {
    data: playerBets,
    isLoading: isPlayerBetsLoading,
    refetch: refetchPlayerBets,
  } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: DICE_FATE_ABI,
    functionName: "getPlayerBets",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const placeBet = async (targetNumber: number, ethAmount: string): Promise<string> => {
    const hash = await writeContractAsync({
      address: contractAddress as `0x${string}`,
      abi: DICE_FATE_ABI,
      functionName: "placeBet",
      args: [targetNumber],
      value: parseEther(ethAmount),
    });

    // Refresh the bet list so the new bet shows immediately.
    await refetchPlayerBets();
    return hash;
  };

  const resolveBet = async (betId: string, randomNumber: string): Promise<string> => {
    const hash = await writeContractAsync({
      address: contractAddress as `0x${string}`,
      abi: DICE_FATE_ABI,
      functionName: "resolveBet",
      args: [BigInt(betId), BigInt(randomNumber)],
    });

    await refetchPlayerBets();
    return hash;
  };

  return {
    placeBet,
    resolveBet,
    contractBalance: contractBalance as bigint | undefined,
    isBalanceLoading,
    playerBets: (playerBets as bigint[] | undefined) ?? [],
    isPlayerBetsLoading,
    refetchPlayerBets,
    isWritePending,
    writeError,
  };
}
