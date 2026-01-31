'use client';

import { useState, useEffect } from 'react';
import { useReadContract, useReadContracts } from 'wagmi';
import { RoundCard } from '@/components/RoundCard';
import { Card, CardContent } from '@/components/ui/card';
import { EMBER_ARENA_ADDRESS, EMBER_ARENA_ABI } from '@/abi/EmberArena';

export default function RoundsPage() {
  const [roundIds, setRoundIds] = useState<bigint[]>([]);

  // Get current round ID
  const { data: currentRoundId } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'currentRoundId',
  });

  // Generate array of round IDs
  useEffect(() => {
    if (currentRoundId !== undefined && currentRoundId > 0n) {
      const ids: bigint[] = [];
      for (let i = currentRoundId; i >= 1n; i--) {
        ids.push(i);
      }
      setRoundIds(ids);
    }
  }, [currentRoundId]);

  // Fetch all rounds
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

  // Get current phase (only for most recent round)
  const { data: currentPhase } = useReadContract({
    address: EMBER_ARENA_ADDRESS,
    abi: EMBER_ARENA_ABI,
    functionName: 'getCurrentPhase',
  });

  const getPhaseForRound = (roundId: bigint): number => {
    if (roundId === currentRoundId && currentPhase !== undefined) {
      return Number(currentPhase);
    }
    // Past rounds are always ended
    return 3;
  };

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">All Rounds</h1>
        <p className="text-zinc-400">
          Browse all Ember Arena rounds, past and present.
        </p>
      </div>

      {roundsData && roundsData.length > 0 ? (
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {roundsData.map((result, idx) => {
            if (result.status !== 'success' || !result.result) return null;
            const round = result.result;
            const phase = getPhaseForRound(round.roundId);
            return (
              <RoundCard
                key={round.roundId.toString()}
                round={round}
                phase={phase}
              />
            );
          })}
        </div>
      ) : currentRoundId === 0n ? (
        <Card className="text-center py-12">
          <CardContent>
            <p className="text-zinc-400">No rounds have been created yet.</p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1, 2, 3].map((i) => (
            <Card key={i} className="animate-pulse">
              <CardContent className="p-6">
                <div className="h-4 bg-zinc-800 rounded w-1/2 mb-4" />
                <div className="h-8 bg-zinc-800 rounded mb-4" />
                <div className="h-4 bg-zinc-800 rounded w-3/4" />
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
