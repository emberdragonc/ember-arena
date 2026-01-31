'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Countdown } from '@/components/Countdown';
import { EMBER_ARENA_ADDRESS, EMBER_ARENA_ABI } from '@/abi/EmberArena';

export default function SubmitPage() {
  const router = useRouter();
  const { address, isConnected } = useAccount();
  const [description, setDescription] = useState('');
  const [metadata, setMetadata] = useState('');

  // Get current round
  const { data: currentRound } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getCurrentRound',
  });

  // Get current phase
  const { data: currentPhase } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getCurrentPhase',
  });

  // Submit idea transaction
  const { writeContract, data: txHash, isPending, error } = useWriteContract();

  // Wait for confirmation
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // Redirect on success
  useEffect(() => {
    if (isSuccess && currentRound) {
      router.push(`/round/${currentRound.roundId.toString()}`);
    }
  }, [isSuccess, currentRound, router]);

  const phase = currentPhase !== undefined ? Number(currentPhase) : 0;
  const isSubmissionPhase = phase === 1;
  const hasActiveRound = currentRound && currentRound.roundId > 0n;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!description.trim()) return;

    writeContract({
      address: EMBER_ARENA_ADDRESS,
      abi: EMBER_ARENA_ABI,
      functionName: 'submitIdea',
      args: [description.trim(), metadata.trim()],
    });
  };

  const isLoading = isPending || isConfirming;

  return (
    <div className="max-w-2xl mx-auto space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">Submit Your Idea</h1>
        <p className="text-zinc-400">
          Share your best idea and let the community back it!
        </p>
      </div>

      {/* Status Card */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            Round Status
            {isSubmissionPhase ? (
              <Badge variant="default">Submissions Open</Badge>
            ) : phase === 2 ? (
              <Badge variant="success">Voting Phase</Badge>
            ) : (
              <Badge variant="outline">No Active Round</Badge>
            )}
          </CardTitle>
          {hasActiveRound && (
            <CardDescription>
              Round #{currentRound.roundId.toString()}
            </CardDescription>
          )}
        </CardHeader>
        {hasActiveRound && isSubmissionPhase && (
          <CardContent>
            <Countdown
              targetTimestamp={Number(currentRound.votingStart)}
              label="Submissions close in"
            />
          </CardContent>
        )}
      </Card>

      {/* Submit Form */}
      {!isConnected ? (
        <Card className="text-center py-12">
          <CardContent className="space-y-4">
            <p className="text-zinc-400">Connect your wallet to submit an idea</p>
            <ConnectButton />
          </CardContent>
        </Card>
      ) : !hasActiveRound ? (
        <Card className="text-center py-12">
          <CardContent>
            <p className="text-zinc-400">No active round. Check back soon!</p>
          </CardContent>
        </Card>
      ) : !isSubmissionPhase ? (
        <Card className="text-center py-12">
          <CardContent>
            <p className="text-zinc-400">
              Submissions are closed. The round is now in {phase === 2 ? 'voting' : 'ended'} phase.
            </p>
            <Button asChild variant="outline" className="mt-4">
              <a href={`/round/${currentRound.roundId.toString()}`}>
                View Current Round
              </a>
            </Button>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardHeader>
            <CardTitle>💡 Your Idea</CardTitle>
            <CardDescription>
              Describe your idea clearly. Good ideas attract more backing!
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="text-sm font-medium text-zinc-300 block mb-2">
                  Description *
                </label>
                <textarea
                  className="flex w-full rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm text-zinc-100 shadow-sm transition-colors placeholder:text-zinc-500 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-orange-500 disabled:cursor-not-allowed disabled:opacity-50 min-h-[120px] resize-y"
                  placeholder="Describe your idea in detail..."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  disabled={isLoading}
                  maxLength={500}
                />
                <p className="text-xs text-zinc-500 mt-1">
                  {description.length}/500 characters
                </p>
              </div>

              <div>
                <label className="text-sm font-medium text-zinc-300 block mb-2">
                  Link (optional)
                </label>
                <Input
                  type="url"
                  placeholder="https://... (IPFS, GitHub, blog post, etc.)"
                  value={metadata}
                  onChange={(e) => setMetadata(e.target.value)}
                  disabled={isLoading}
                />
                <p className="text-xs text-zinc-500 mt-1">
                  Add a link to more details, mockups, or documentation
                </p>
              </div>

              {error && (
                <div className="p-3 bg-red-900/30 border border-red-700 rounded-lg">
                  <p className="text-sm text-red-400">
                    Error: {error.message || 'Transaction failed'}
                  </p>
                </div>
              )}

              <Button
                type="submit"
                disabled={!description.trim() || isLoading}
                className="w-full"
                size="lg"
              >
                {isPending ? 'Confirm in Wallet...' : isConfirming ? 'Submitting...' : '🔥 Submit Idea'}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
