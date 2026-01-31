'use client';

import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { baseSepolia } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'Ember Arena',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'ember-arena-dev',
  chains: [baseSepolia],
  ssr: true,
});
