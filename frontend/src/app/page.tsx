'use client';

import { useReadContract, useReadContracts } from 'wagmi';
import Link from 'next/link';
import { RoundCard } from '@/components/RoundCard';
import { IdeaCard } from '@/components/IdeaCard';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { EMBER_ARENA_ADDRESS, EMBER_ARENA_ABI } from '@/abi/EmberArena';

export default function Home() {
  // Get current round
  const { data: currentRound, refetch: refetchRound } = useReadContract({
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

  // Get idea IDs for current round
  const { data: ideaIds } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getRoundIdeaIds',
    args: currentRound ? [currentRound.roundId] : undefined,
    query: { enabled: !!currentRound && currentRound.roundId > 0n },
  });

  // Get all ideas for current round
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

  const phase = currentPhase !== undefined ? Number(currentPhase) : 0;
  const hasActiveRound = currentRound && currentRound.roundId > 0n;

  const handleBackSuccess = () => {
    refetchRound();
    refetchIdeas();
  };

  return (
    <div className="space-y-8">
      {/* Hero Section */}
      <section className="text-center py-12">
        <h1 className="text-4xl md:text-6xl font-bold mb-4">
          <span className="text-orange-500">🔥 Ember</span> Arena
        </h1>
        <p className="text-xl text-zinc-400 max-w-2xl mx-auto mb-8">
          The idea backing prediction market. Submit your best ideas, back the ones you believe in,
          and winners split the pool.
        </p>
        <div className="flex flex-wrap justify-center gap-4">
          {phase === 1 && (
            <Button asChild size="lg">
              <Link href="/submit">💡 Submit Your Idea</Link>
            </Button>
          )}
          <Button asChild variant="outline" size="lg">
            <Link href="/rounds">View All Rounds</Link>
          </Button>
        </div>
      </section>

      {/* How It Works */}
      <section className="grid md:grid-cols-3 gap-6 py-8">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <span className="text-2xl">💡</span> Submit Ideas
            </CardTitle>
          </CardHeader>
          <CardContent className="text-zinc-400">
            During the submission phase (24h), submit your best ideas.
            Each round accepts up to 100 ideas.
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <span className="text-2xl">🔥</span> Back Ideas
            </CardTitle>
          </CardHeader>
          <CardContent className="text-zinc-400">
            During the voting phase (24h), stake $EMBER on ideas you believe in.
            Higher backing = higher potential returns.
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <span className="text-2xl">💰</span> Win Rewards
            </CardTitle>
          </CardHeader>
          <CardContent className="text-zinc-400">
            The winning idea's backers split 80% of the total pool.
            20% is burned forever. 🔥
          </CardContent>
        </Card>
      </section>

      {/* Current Round */}
      <section>
        <h2 className="text-2xl font-bold mb-6">Current Round</h2>
        {hasActiveRound ? (
          <div className="space-y-6">
            <RoundCard round={currentRound} phase={phase} />

            {/* Ideas */}
            {ideas && ideas.length > 0 && (
              <div>
                <h3 className="text-xl font-semibold mb-4">
                  Ideas ({ideas.length})
                </h3>
                <div className="grid md:grid-cols-2 gap-4">
                  {ideas.map((result, idx) => {
                    if (result.status !== 'success' || !result.result) return null;
                    const idea = result.result;
                    return (
                      <IdeaCard
                        key={idea.ideaId.toString()}
                        idea={idea}
                        phase={phase}
                        totalPool={currentRound.totalPool}
                        onBackSuccess={handleBackSuccess}
                      />
                    );
                  })}
                </div>
              </div>
            )}

            {(!ideas || ideas.length === 0) && phase === 1 && (
              <Card className="text-center py-12">
                <CardContent>
                  <p className="text-zinc-400 mb-4">No ideas submitted yet. Be the first!</p>
                  <Button asChild>
                    <Link href="/submit">💡 Submit Your Idea</Link>
                  </Button>
                </CardContent>
              </Card>
            )}
          </div>
        ) : (
          <Card className="text-center py-12">
            <CardContent>
              <p className="text-zinc-400 mb-2">No active round</p>
              <p className="text-sm text-zinc-500">
                Check back soon or view past rounds.
              </p>
            </CardContent>
          </Card>
        )}
      </section>
    </div>
  );
}
