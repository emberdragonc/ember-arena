'use client';

import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { EMBER_ARENA_ADDRESS, EMBER_ARENA_ABI, ERC20_ABI } from '@/abi/EmberArena';

interface BackingFormProps {
  ideaId: bigint;
  onSuccess?: () => void;
  onCancel?: () => void;
}

export function BackingForm({ ideaId, onSuccess, onCancel }: BackingFormProps) {
  const [amount, setAmount] = useState('');
  const [needsApproval, setNeedsApproval] = useState(true);
  const { address } = useAccount();

  // Get EMBER token address
  const { data: emberTokenAddress } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'emberToken',
  });

  // Get user's EMBER balance
  const { data: balance } = useReadContract({
    address: emberTokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!emberTokenAddress },
  });

  // Get current allowance
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: emberTokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, EMBER_ARENA_ADDRESS] : undefined,
    query: { enabled: !!address && !!emberTokenAddress },
  });

  // Check if approval is needed
  useEffect(() => {
    if (allowance !== undefined && amount) {
      try {
        const amountWei = parseEther(amount);
        setNeedsApproval(allowance < amountWei);
      } catch {
        setNeedsApproval(true);
      }
    }
  }, [allowance, amount]);

  // Approve transaction
  const { writeContract: approve, data: approveHash, isPending: isApproving } = useWriteContract();

  // Back idea transaction
  const { writeContract: backIdea, data: backHash, isPending: isBacking } = useWriteContract();

  // Wait for approval
  const { isLoading: isApprovalConfirming, isSuccess: isApprovalConfirmed } = useWaitForTransactionReceipt({
    hash: approveHash,
  });

  // Wait for backing
  const { isLoading: isBackingConfirming, isSuccess: isBackingConfirmed } = useWaitForTransactionReceipt({
    hash: backHash,
  });

  // Refetch allowance after approval
  useEffect(() => {
    if (isApprovalConfirmed) {
      refetchAllowance();
    }
  }, [isApprovalConfirmed, refetchAllowance]);

  // Call onSuccess when backing is confirmed
  useEffect(() => {
    if (isBackingConfirmed) {
      onSuccess?.();
    }
  }, [isBackingConfirmed, onSuccess]);

  const handleApprove = () => {
    if (!emberTokenAddress || !amount) return;
    approve({
      address: emberTokenAddress as `0x${string}`,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [EMBER_ARENA_ADDRESS, parseEther(amount)],
    });
  };

  const handleBack = () => {
    if (!amount) return;
    backIdea({
      address: EMBER_ARENA_ADDRESS,
      abi: EMBER_ARENA_ABI,
      functionName: 'backIdea',
      args: [ideaId, parseEther(amount)],
    });
  };

  const isLoading = isApproving || isApprovalConfirming || isBacking || isBackingConfirming;

  return (
    <div className="space-y-3 p-4 bg-zinc-800 rounded-lg">
      <div>
        <label className="text-sm text-zinc-400 block mb-1">Amount (EMBER)</label>
        <Input
          type="number"
          placeholder="100"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          disabled={isLoading}
        />
        {balance !== undefined && (
          <p className="text-xs text-zinc-500 mt-1">
            Balance: {formatEther(balance)} EMBER
            <button
              type="button"
              className="text-orange-500 ml-2 hover:underline"
              onClick={() => setAmount(formatEther(balance))}
            >
              Max
            </button>
          </p>
        )}
      </div>

      <div className="flex gap-2">
        {needsApproval ? (
          <Button
            onClick={handleApprove}
            disabled={!amount || isLoading}
            className="flex-1"
          >
            {isApproving || isApprovalConfirming ? 'Approving...' : 'Approve EMBER'}
          </Button>
        ) : (
          <Button
            onClick={handleBack}
            disabled={!amount || isLoading}
            className="flex-1"
          >
            {isBacking || isBackingConfirming ? 'Backing...' : '🔥 Back Idea'}
          </Button>
        )}
        <Button variant="outline" onClick={onCancel} disabled={isLoading}>
          Cancel
        </Button>
      </div>
    </div>
  );
}
