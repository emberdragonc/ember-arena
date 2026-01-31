'use client';

import Link from 'next/link';
import { ConnectButton } from '@rainbow-me/rainbowkit';

export function Header() {
  return (
    <header className="border-b border-zinc-800 bg-zinc-950/80 backdrop-blur-sm sticky top-0 z-50">
      <div className="container mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center gap-8">
          <Link href="/" className="flex items-center gap-2">
            <span className="text-2xl">🔥</span>
            <span className="font-bold text-xl text-orange-500">Ember Arena</span>
          </Link>
          
          <nav className="hidden md:flex items-center gap-6">
            <Link
              href="/rounds"
              className="text-zinc-400 hover:text-zinc-100 transition-colors"
            >
              All Rounds
            </Link>
            <Link
              href="/submit"
              className="text-zinc-400 hover:text-zinc-100 transition-colors"
            >
              Submit Idea
            </Link>
            <Link
              href="/my-backings"
              className="text-zinc-400 hover:text-zinc-100 transition-colors"
            >
              My Backings
            </Link>
          </nav>
        </div>

        <ConnectButton />
      </div>
    </header>
  );
}
