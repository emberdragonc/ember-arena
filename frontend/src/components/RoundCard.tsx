'use client';

import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Countdown } from '@/components/Countdown';
import { formatEmber, getPhaseLabel } from '@/lib/utils';

interface Round {
  roundId: bigint;
  submissionStart: bigint;
  votingStart: bigint;
  votingEnd: bigint;
  totalPool: bigint;
  winningIdeaId: bigint;
  resolved: boolean;
  ideaCount: bigint;
}

interface RoundCardProps {
  round: Round;
  phase: number;
  showLink?: boolean;
}

export function RoundCard({ round, phase, showLink = true }: RoundCardProps) {
  const getPhaseVariant = () => {
    switch (phase) {
      case 1:
        return 'default';
      case 2:
        return 'success';
      case 3:
        return round.resolved ? 'secondary' : 'warning';
      default:
        return 'outline';
    }
  };

  const getTargetTimestamp = () => {
    if (phase === 1) return Number(round.votingStart);
    if (phase === 2) return Number(round.votingEnd);
    return 0;
  };

  const getCountdownLabel = () => {
    if (phase === 1) return 'Submissions end in';
    if (phase === 2) return 'Voting ends in';
    return '';
  };

  return (
    <Card className="hover:border-zinc-700 transition-colors">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-xl">Round #{round.roundId.toString()}</CardTitle>
          <Badge variant={getPhaseVariant()}>{getPhaseLabel(phase)}</Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <p className="text-sm text-zinc-400">Total Pool</p>
            <p className="text-lg font-semibold text-orange-500">
              {formatEmber(round.totalPool)} EMBER
            </p>
          </div>
          <div>
            <p className="text-sm text-zinc-400">Ideas</p>
            <p className="text-lg font-semibold">{round.ideaCount.toString()}</p>
          </div>
        </div>

        {(phase === 1 || phase === 2) && (
          <Countdown
            targetTimestamp={getTargetTimestamp()}
            label={getCountdownLabel()}
          />
        )}

        {round.resolved && round.winningIdeaId > 0n && (
          <div className="pt-2 border-t border-zinc-800">
            <p className="text-sm text-zinc-400">Winning Idea</p>
            <p className="text-lg font-semibold text-green-500">
              #{round.winningIdeaId.toString()}
            </p>
          </div>
        )}

        {showLink && (
          <Button asChild variant="outline" className="w-full">
            <Link href={`/round/${round.roundId.toString()}`}>
              View Round Details →
            </Link>
          </Button>
        )}
      </CardContent>
    </Card>
  );
}
