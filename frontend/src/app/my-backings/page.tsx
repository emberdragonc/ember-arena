'use client';

import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useReadContracts } from 'wagmi';
import Link from 'next/link';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ClaimButton } from '@/components/ClaimButton';
import { formatEmber, formatAddress } from '@/lib/utils';
import { EMBER_ARENA_ADDRESS, EMBER_ARENA_ABI } from '@/abi/EmberArena';

interface BackingInfo {
  roundId: bigint;
  ideaId: bigint;
  amount: bigint;
  claimed: boolean;
  ideaDescription: string;
  ideaIsWinner: boolean;
  roundResolved: boolean;
  winningIdeaId: bigint;
}

export default function MyBackingsPage() {
  const { address, isConnected } = useAccount();
  const [backings, setBackings] = useState<BackingInfo[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // Get current round ID
  const { data: currentRoundId } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'currentRoundId',
  });

  // Generate round IDs to check
  const roundIds: bigint[] = [];
  if (currentRoundId) {
    for (let i = currentRoundId; i >= 1n; i--) {
      roundIds.push(i);
    }
  }

  // Fetch user backings for each round
  const backingContracts = roundIds.map((id) => ({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getUserBackings' as const,
    args: address ? [address, id] as const : undefined,
  }));

  const { data: userBackingsData, refetch: refetchBackings } = useReadContracts({
    contracts: backingContracts,
    query: { enabled: !!address && backingContracts.length > 0 },
  });

  // Fetch round info for all rounds
  const roundContracts = roundIds.map((id) => ({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getRoundInfo' as const,
    args: [id] as const,
  }));

  const { data: roundsData } = useReadContracts({
    contracts: roundContracts,
    query: { enabled: roundContracts.length > 0 },
  });

  // Process backings data
  useEffect(() => {
    const processBackings = async () => {
      if (!userBackingsData || !roundsData || !address) {
        setIsLoading(false);
        return;
      }

      const allBackings: BackingInfo[] = [];

      for (let i = 0; i < roundIds.length; i++) {
        const backingResult = userBackingsData[i];
        const roundResult = roundsData[i];

        if (
          backingResult?.status !== 'success' ||
          roundResult?.status !== 'success' ||
          !backingResult.result ||
          !roundResult.result
        ) {
          continue;
        }

        const ideaIds = backingResult.result as bigint[];
        const round = roundResult.result;

        for (const ideaId of ideaIds) {
          allBackings.push({
            roundId: roundIds[i],
            ideaId,
            amount: 0n, // Will be filled in
            claimed: false,
            ideaDescription: '',
            ideaIsWinner: ideaId === round.winningIdeaId,
            roundResolved: round.resolved,
            winningIdeaId: round.winningIdeaId,
          });
        }
      }

      setBackings(allBackings);
      setIsLoading(false);
    };

    processBackings();
  }, [userBackingsData, roundsData, address]);

  // Fetch detailed backing info for each backing
  const detailContracts = backings.map((b) => ({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getUserBackingForIdea' as const,
    args: address ? [address, b.roundId, b.ideaId] as const : undefined,
  }));

  const { data: detailsData } = useReadContracts({
    contracts: detailContracts,
    query: { enabled: !!address && detailContracts.length > 0 },
  });

  // Fetch idea descriptions
  const ideaContracts = backings.map((b) => ({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getIdea' as const,
    args: [b.ideaId] as const,
  }));

  const { data: ideasData } = useReadContracts({
    contracts: ideaContracts,
    query: { enabled: ideaContracts.length > 0 },
  });

  // Merge details into backings
  const enrichedBackings = backings.map((b, i) => {
    const detail = detailsData?.[i];
    const idea = ideasData?.[i];
    return {
      ...b,
      amount: detail?.status === 'success' && detail.result ? (detail.result as { amount: bigint }).amount : 0n,
      claimed: detail?.status === 'success' && detail.result ? (detail.result as { claimed: boolean }).claimed : false,
      ideaDescription: idea?.status === 'success' && idea.result ? (idea.result as { description: string }).description : '',
    };
  }).filter((b) => b.amount > 0n);

  if (!isConnected) {
    return (
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">My Backings</h1>
        <Card className="text-center py-12">
          <CardContent className="space-y-4">
            <p className="text-zinc-400">Connect your wallet to view your backings</p>
            <ConnectButton />
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">My Backings</h1>
        <p className="text-zinc-400">
          Your backing history across all rounds.
        </p>
      </div>

      {isLoading ? (
        <div className="grid gap-4">
          {[1, 2, 3].map((i) => (
            <Card key={i} className="animate-pulse">
              <CardContent className="p-6">
                <div className="h-4 bg-zinc-800 rounded w-1/3 mb-4" />
                <div className="h-6 bg-zinc-800 rounded w-full mb-2" />
                <div className="h-4 bg-zinc-800 rounded w-1/2" />
              </CardContent>
            </Card>
          ))}
        </div>
      ) : enrichedBackings.length === 0 ? (
        <Card className="text-center py-12">
          <CardContent className="space-y-4">
            <p className="text-zinc-400">You haven't backed any ideas yet.</p>
            <Button asChild>
              <Link href="/">Browse Current Round</Link>
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {enrichedBackings.map((backing, idx) => (
            <Card key={`${backing.roundId}-${backing.ideaId}`}>
              <CardHeader className="pb-2">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">
                    Round #{backing.roundId.toString()} - Idea #{backing.ideaId.toString()}
                  </CardTitle>
                  <div className="flex gap-2">
                    {backing.ideaIsWinner && (
                      <Badge variant="success">🏆 Winner</Badge>
                    )}
                    {backing.claimed && (
                      <Badge variant="secondary">Claimed</Badge>
                    )}
                    {backing.roundResolved && !backing.ideaIsWinner && (
                      <Badge variant="outline">Lost</Badge>
                    )}
                    {!backing.roundResolved && (
                      <Badge variant="warning">Pending</Badge>
                    )}
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <p className="text-zinc-300 line-clamp-2">
                  {backing.ideaDescription || 'Loading...'}
                </p>
                
                <div className="flex items-center justify-between text-sm">
                  <span className="text-zinc-400">Your Backing:</span>
                  <span className="font-semibold text-orange-500">
                    {formatEmber(backing.amount)} EMBER
                  </span>
                </div>

                {backing.roundResolved && backing.ideaIsWinner && !backing.claimed && (
                  <ClaimButton
                    roundId={backing.roundId}
                    winningIdeaId={backing.ideaId}
                    onSuccess={() => refetchBackings()}
                  />
                )}

                <Button asChild variant="outline" size="sm">
                  <Link href={`/round/${backing.roundId.toString()}`}>
                    View Round →
                  </Link>
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
