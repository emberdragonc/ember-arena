'use client';

import { useEffect } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import { Button } from '@/components/ui/button';
import { EMBER_ARENA_ADDRESS, EMBER_ARENA_ABI } from '@/abi/EmberArena';
import { formatEmber } from '@/lib/utils';

interface ClaimButtonProps {
  roundId: bigint;
  winningIdeaId: bigint;
  onSuccess?: () => void;
}

export function ClaimButton({ roundId, winningIdeaId, onSuccess }: ClaimButtonProps) {
  const { address } = useAccount();

  // Get user's backing for the winning idea
  const { data: backing } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getUserBackingForIdea',
    args: address ? [address, roundId, winningIdeaId] : undefined,
    query: { enabled: !!address },
  });

  // Calculate potential winnings
  const { data: potentialWinnings } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'calculatePotentialWinnings',
    args: address ? [roundId, winningIdeaId, address] : undefined,
    query: { enabled: !!address },
  });

  // Claim transaction
  const { writeContract: claim, data: claimHash, isPending } = useWriteContract();

  // Wait for confirmation
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: claimHash,
  });

  useEffect(() => {
    if (isSuccess) {
      onSuccess?.();
    }
  }, [isSuccess, onSuccess]);

  // Check if user can claim
  const canClaim = backing &&
    backing.amount > 0n &&
    !backing.claimed &&
    potentialWinnings &&
    potentialWinnings > 0n;

  const hasClaimed = backing?.claimed;

  if (!backing || backing.amount === 0n) {
    return null; // User didn't back the winning idea
  }

  const handleClaim = () => {
    claim({
      address: EMBER_ARENA_ADDRESS,
      abi: EMBER_ARENA_ABI,
      functionName: 'claimWinnings',
      args: [roundId],
    });
  };

  if (hasClaimed) {
    return (
      <div className="p-4 bg-green-900/30 border border-green-700 rounded-lg">
        <p className="text-green-400 font-semibold">✅ Winnings Claimed!</p>
        <p className="text-sm text-zinc-400">
          You received your share of the pool.
        </p>
      </div>
    );
  }

  return (
    <div className="p-4 bg-orange-900/30 border border-orange-700 rounded-lg space-y-3">
      <div>
        <p className="text-orange-400 font-semibold">🎉 You backed the winner!</p>
        <p className="text-sm text-zinc-400">
          Your backing: {formatEmber(backing.amount)} EMBER
        </p>
        {potentialWinnings && (
          <p className="text-lg font-bold text-green-400">
            Claimable: {formatEmber(potentialWinnings)} EMBER
          </p>
        )}
      </div>
      <Button
        onClick={handleClaim}
        disabled={!canClaim || isPending || isConfirming}
        className="w-full"
      >
        {isPending || isConfirming ? 'Claiming...' : '💰 Claim Winnings'}
      </Button>
    </div>
  );
}
