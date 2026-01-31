'use client';

import { useState, useEffect } from 'react';

interface CountdownProps {
  targetTimestamp: number;
  label?: string;
  onComplete?: () => void;
}

export function Countdown({ targetTimestamp, label, onComplete }: CountdownProps) {
  const [timeLeft, setTimeLeft] = useState<{
    hours: number;
    minutes: number;
    seconds: number;
    isExpired: boolean;
  }>({ hours: 0, minutes: 0, seconds: 0, isExpired: false });

  useEffect(() => {
    const calculateTimeLeft = () => {
      const now = Math.floor(Date.now() / 1000);
      const diff = targetTimestamp - now;

      if (diff <= 0) {
        setTimeLeft({ hours: 0, minutes: 0, seconds: 0, isExpired: true });
        onComplete?.();
        return;
      }

      const hours = Math.floor(diff / 3600);
      const minutes = Math.floor((diff % 3600) / 60);
      const seconds = diff % 60;

      setTimeLeft({ hours, minutes, seconds, isExpired: false });
    };

    calculateTimeLeft();
    const interval = setInterval(calculateTimeLeft, 1000);

    return () => clearInterval(interval);
  }, [targetTimestamp, onComplete]);

  if (timeLeft.isExpired) {
    return (
      <div className="text-center">
        {label && <p className="text-sm text-zinc-400 mb-1">{label}</p>}
        <p className="text-lg font-semibold text-orange-500">Phase Complete</p>
      </div>
    );
  }

  return (
    <div className="text-center">
      {label && <p className="text-sm text-zinc-400 mb-2">{label}</p>}
      <div className="flex items-center justify-center gap-2">
        <TimeUnit value={timeLeft.hours} label="HRS" />
        <span className="text-2xl font-bold text-zinc-500">:</span>
        <TimeUnit value={timeLeft.minutes} label="MIN" />
        <span className="text-2xl font-bold text-zinc-500">:</span>
        <TimeUnit value={timeLeft.seconds} label="SEC" />
      </div>
    </div>
  );
}

function TimeUnit({ value, label }: { value: number; label: string }) {
  return (
    <div className="flex flex-col items-center">
      <div className="bg-zinc-800 rounded-lg px-3 py-2 min-w-[60px]">
        <span className="text-2xl font-bold text-orange-500 font-mono">
          {value.toString().padStart(2, '0')}
        </span>
      </div>
      <span className="text-xs text-zinc-500 mt-1">{label}</span>
    </div>
  );
}
