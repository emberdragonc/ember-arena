'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { BackingForm } from '@/components/BackingForm';
import { formatEmber, formatAddress } from '@/lib/utils';
import { useAccount } from 'wagmi';

interface Idea {
  ideaId: bigint;
  roundId: bigint;
  creator: string;
  description: string;
  metadata: string;
  totalBacking: bigint;
  isWinner: boolean;
}

interface IdeaCardProps {
  idea: Idea;
  phase: number;
  totalPool?: bigint;
  onBackSuccess?: () => void;
}

export function IdeaCard({ idea, phase, totalPool = 0n, onBackSuccess }: IdeaCardProps) {
  const [showBackingForm, setShowBackingForm] = useState(false);
  const { address } = useAccount();
  const isCreator = address?.toLowerCase() === idea.creator.toLowerCase();

  // Calculate backing percentage
  const backingPercentage = totalPool > 0n
    ? Number((idea.totalBacking * 100n) / totalPool)
    : 0;

  return (
    <Card className={`${idea.isWinner ? 'border-green-500 ring-1 ring-green-500/50' : ''}`}>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between gap-2">
          <CardTitle className="text-lg">Idea #{idea.ideaId.toString()}</CardTitle>
          <div className="flex gap-2">
            {idea.isWinner && (
              <Badge variant="success">🏆 Winner</Badge>
            )}
            {isCreator && (
              <Badge variant="secondary">Your Idea</Badge>
            )}
          </div>
        </div>
        <p className="text-sm text-zinc-400">
          by {formatAddress(idea.creator)}
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        <p className="text-zinc-200">{idea.description}</p>
        
        {idea.metadata && (
          <a
            href={idea.metadata}
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-orange-500 hover:underline"
          >
            View Details →
          </a>
        )}

        <div className="pt-4 border-t border-zinc-800">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-zinc-400">Total Backing</span>
            <span className="font-semibold text-orange-500">
              {formatEmber(idea.totalBacking)} EMBER
            </span>
          </div>
          
          {totalPool > 0n && (
            <div className="w-full bg-zinc-800 rounded-full h-2">
              <div
                className="bg-orange-500 h-2 rounded-full transition-all"
                style={{ width: `${Math.min(backingPercentage, 100)}%` }}
              />
            </div>
          )}
          
          <p className="text-xs text-zinc-500 mt-1">
            {backingPercentage.toFixed(1)}% of total pool
          </p>
        </div>

        {phase === 2 && !showBackingForm && (
          <Button
            onClick={() => setShowBackingForm(true)}
            className="w-full"
          >
            🔥 Back This Idea
          </Button>
        )}

        {showBackingForm && (
          <BackingForm
            ideaId={idea.ideaId}
            onSuccess={() => {
              setShowBackingForm(false);
              onBackSuccess?.();
            }}
            onCancel={() => setShowBackingForm(false)}
          />
        )}
      </CardContent>
    </Card>
  );
}
