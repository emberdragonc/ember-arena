import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function formatEmber(amount: bigint, decimals = 18): string {
  const value = Number(amount) / 10 ** decimals;
  if (value >= 1000000) {
    return `${(value / 1000000).toFixed(2)}M`;
  }
  if (value >= 1000) {
    return `${(value / 1000).toFixed(2)}K`;
  }
  return value.toFixed(2);
}

export function getPhaseLabel(phase: number): string {
  switch (phase) {
    case 0:
      return 'No Active Round';
    case 1:
      return 'Submission Phase';
    case 2:
      return 'Voting Phase';
    case 3:
      return 'Round Ended';
    default:
      return 'Unknown';
  }
}

export function getPhaseColor(phase: number): string {
  switch (phase) {
    case 1:
      return 'bg-blue-500';
    case 2:
      return 'bg-green-500';
    case 3:
      return 'bg-gray-500';
    default:
      return 'bg-gray-400';
  }
}
