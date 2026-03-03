import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther } from 'viem';
import { DICE_FATE_ABI } from './abi';
import { DICE_FATE_CONTRACT } from './config';

export function useDiceFate(contractAddress: string = DICE_FATE_CONTRACT) {
  const { address } = useAccount();
  
  const {
    writeContractAsync,
    isPending: isWritePending,
    error: writeError,
  } = useWriteContract();

  const {
    data: contractBalance,
    isLoading: isBalanceLoading,
  } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: DICE_FATE_ABI as any,
    functionName: 'contractBalance',
  });

  const {
    data: playerBets,
    isLoading: isPlayerBetsLoading,
    refetch: refetchPlayerBets,
  } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: DICE_FATE_ABI as any,
    functionName: 'getPlayerBets',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const placeBet = async (targetNumber: number, ethAmount: string) => {
    try {
      const hash = await writeContractAsync({
        address: contractAddress as `0x${string}`,
        abi: DICE_FATE_ABI as any,
        functionName: 'placeBet',
        args: [targetNumber],
        value: parseEther(ethAmount),
      });
      
      return hash;
    } catch (error) {
      console.error('Error placing bet:', error);
      throw error;
    }
  };

  const resolveBet = async (betId: string, randomNumber: string) => {
    try {
      const hash = await writeContractAsync({
        address: contractAddress as `0x${string}`,
        abi: DICE_FATE_ABI as any,
        functionName: 'resolveBet',
        args: [BigInt(betId), BigInt(randomNumber)],
      });
      
      return hash;
    } catch (error) {
      console.error('Error resolving bet:', error);
      throw error;
    }
  };

  return {
    placeBet,
    resolveBet,
    contractBalance,
    isBalanceLoading,
    playerBets,
    isPlayerBetsLoading,
    refetchPlayerBets,
    isWritePending,
    writeError,
  };
}
