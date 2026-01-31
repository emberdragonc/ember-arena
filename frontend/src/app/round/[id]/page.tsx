'use client';

import { use } from 'react';
import { useReadContract, useReadContracts } from 'wagmi';
import Link from 'next/link';
import { RoundCard } from '@/components/RoundCard';
import { IdeaCard } from '@/components/IdeaCard';
import { ClaimButton } from '@/components/ClaimButton';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { EMBER_ARENA_ADDRESS, EMBER_ARENA_ABI } from '@/abi/EmberArena';

interface PageProps {
  params: Promise<{ id: string }>;
}

export default function RoundDetailPage({ params }: PageProps) {
  const { id } = use(params);
  const roundId = BigInt(id);

  // Get round info
  const { data: round, refetch: refetchRound } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getRoundInfo',
    args: [roundId],
  });

  // Get current round ID to determine phase
  const { data: currentRoundId } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'currentRoundId',
  });

  // Get current phase (only applicable if this is the current round)
  const { data: currentPhase } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getCurrentPhase',
  });

  // Get idea IDs for this round
  const { data: ideaIds } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getRoundIdeaIds',
    args: [roundId],
  });

  // Get all ideas
  const ideaContracts = (ideaIds || []).map((id) => ({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getIdea' as const,
    args: [id] as const,
  }));

  const { data: ideas, refetch: refetchIdeas } = useReadContracts({
    contracts: ideaContracts,
    query: { enabled: ideaContracts.length > 0 },
  });

  // Determine phase for this round
  const phase = roundId === currentRoundId && currentPhase !== undefined
    ? Number(currentPhase)
    : 3; // Past rounds show as ended

  const handleBackSuccess = () => {
    refetchRound();
    refetchIdeas();
  };

  if (!round) {
    return (
      <div className="space-y-4">
        <Button asChild variant="ghost">
          <Link href="/rounds">← Back to Rounds</Link>
        </Button>
        <Card className="animate-pulse">
          <CardContent className="p-6">
            <div className="h-8 bg-zinc-800 rounded w-1/3 mb-4" />
            <div className="h-4 bg-zinc-800 rounded w-full mb-2" />
            <div className="h-4 bg-zinc-800 rounded w-2/3" />
          </CardContent>
        </Card>
      </div>
    );
  }

  // Sort ideas by totalBacking descending
  const sortedIdeas = ideas
    ? [...ideas]
        .filter((r) => r.status === 'success' && r.result)
        .map((r) => r.result!)
        .sort((a, b) => Number(b.totalBacking - a.totalBacking))
    : [];

  return (
    <div className="space-y-8">
      <Button asChild variant="ghost">
        <Link href="/rounds">← Back to Rounds</Link>
      </Button>

      {/* Round Info */}
      <RoundCard round={round} phase={phase} showLink={false} />

      {/* Claim Button for resolved rounds */}
      {round.resolved && round.winningIdeaId > 0n && (
        <ClaimButton
          roundId={roundId}
          winningIdeaId={round.winningIdeaId}
          onSuccess={() => {
            refetchRound();
            refetchIdeas();
          }}
        />
      )}

      {/* Ideas */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-semibold">
            Ideas ({sortedIdeas.length})
          </h2>
          {phase === 1 && (
            <Button asChild size="sm">
              <Link href="/submit">💡 Submit Idea</Link>
            </Button>
          )}
        </div>

        {sortedIdeas.length > 0 ? (
          <div className="grid md:grid-cols-2 gap-4">
            {sortedIdeas.map((idea) => (
              <IdeaCard
                key={idea.ideaId.toString()}
                idea={idea}
                phase={phase}
                totalPool={round.totalPool}
                onBackSuccess={handleBackSuccess}
              />
            ))}
          </div>
        ) : (
          <Card className="text-center py-12">
            <CardContent>
              <p className="text-zinc-400">
                {phase === 1
                  ? 'No ideas yet. Be the first to submit!'
                  : 'No ideas were submitted for this round.'}
              </p>
            </CardContent>
          </Card>
        )}
      </section>
    </div>
  );
}
