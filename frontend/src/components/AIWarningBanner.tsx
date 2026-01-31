"use client";

import { useState, useEffect } from "react";
import { AlertTriangle, X } from "lucide-react";

const STORAGE_KEY = "ember-arena-ai-warning-dismissed";

export function AIWarningBanner() {
  const [isDismissed, setIsDismissed] = useState(true); // Start hidden to prevent flash
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    // Check localStorage after mount
    const dismissed = localStorage.getItem(STORAGE_KEY);
    setIsDismissed(dismissed === "true");
    setIsLoaded(true);
  }, []);

  const handleDismiss = () => {
    localStorage.setItem(STORAGE_KEY, "true");
    setIsDismissed(true);
  };

  // Don't render until we've checked localStorage
  if (!isLoaded || isDismissed) {
    return null;
  }

  return (
    <div className="bg-amber-500/90 text-black sticky top-0 z-50">
      <div className="container mx-auto px-4 py-3">
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-3 flex-1">
            <AlertTriangle className="h-5 w-5 flex-shrink-0" />
            <p className="text-sm font-medium">
              <span className="font-bold">⚠️ AI-Built Application:</span>{" "}
              This application was built and audited by AI agents. Use at your own risk. 
              Smart contracts are experimental.
            </p>
          </div>
          <button
            onClick={handleDismiss}
            className="p-1 hover:bg-amber-600/50 rounded transition-colors flex-shrink-0"
            aria-label="Dismiss warning"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
      </div>
    </div>
  );
}

// Modal version for first-time visitors
export function AIWarningModal() {
  const [isOpen, setIsOpen] = useState(false);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    const acknowledged = localStorage.getItem(STORAGE_KEY);
    if (!acknowledged) {
      setIsOpen(true);
    }
    setIsLoaded(true);
  }, []);

  const handleAcknowledge = () => {
    localStorage.setItem(STORAGE_KEY, "true");
    setIsOpen(false);
  };

  if (!isLoaded || !isOpen) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
      <div className="bg-zinc-900 border border-amber-500/50 rounded-xl max-w-md w-full p-6 shadow-2xl">
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2 bg-amber-500/20 rounded-lg">
            <AlertTriangle className="h-6 w-6 text-amber-500" />
          </div>
          <h2 className="text-xl font-bold text-amber-500">⚠️ Important Notice</h2>
        </div>
        
        <div className="space-y-4 text-zinc-300">
          <p className="text-sm leading-relaxed">
            <strong className="text-white">This application was built and audited by AI agents.</strong>
          </p>
          
          <ul className="text-sm space-y-2 list-disc list-inside text-zinc-400">
            <li>Smart contracts are <strong className="text-amber-400">experimental</strong></li>
            <li>Code has not been audited by human security experts</li>
            <li>Use at your own risk - only use funds you can afford to lose</li>
            <li>This is deployed on testnet for evaluation purposes</li>
          </ul>
          
          <p className="text-xs text-zinc-500">
            By continuing, you acknowledge that you understand these risks.
          </p>
        </div>
        
        <button
          onClick={handleAcknowledge}
          className="mt-6 w-full bg-amber-500 hover:bg-amber-600 text-black font-bold py-3 px-4 rounded-lg transition-colors"
        >
          I Understand, Continue
        </button>
      </div>
    </div>
  );
}
