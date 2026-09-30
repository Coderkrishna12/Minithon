"use client";

import { useEffect, useState } from "react";

type Result =
  | { status: "found"; count: number; hash: string; candidates: number }
  | { status: "clean"; hash: string; candidates: number; crackTime: string };

const GUESSES_PER_SECOND = 1e10;

async function sha1Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
}

function estimateCrackTime(password: string): string {
  let pool = 0;
  if (/[a-z]/.test(password)) pool += 26;
  if (/[A-Z]/.test(password)) pool += 26;
  if (/[0-9]/.test(password)) pool += 10;
  if (/[^a-zA-Z0-9]/.test(password)) pool += 33;
  const seconds = Math.pow(pool, password.length) / 2 / GUESSES_PER_SECOND;

  const units: [number, string][] = [
    [60 * 60 * 24 * 365 * 100, "centuries"],
    [60 * 60 * 24 * 365, "years"],
    [60 * 60 * 24, "days"],
    [60 * 60, "hours"],
    [60, "minutes"],
    [1, "seconds"],
  ];
  if (!isFinite(seconds) || seconds > 60 * 60 * 24 * 365 * 1e6) return "millions of years";
  for (const [size, label] of units) {
    if (seconds >= size) return `~${Math.round(seconds / size).toLocaleString()} ${label}`;
  }
  return "instantly";
}

function useCountUp(target: number, durationMs = 1400) {
  const [value, setValue] = useState(0);
  useEffect(() => {
    let frame: number;
    const start = performance.now();
    const tick = (now: number) => {
      const t = Math.min((now - start) / durationMs, 1);
      setValue(Math.round(target * (1 - Math.pow(1 - t, 3))));
      if (t < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [target, durationMs]);
  return value;
}

function HashReveal({ hash, candidates }: { hash: string; candidates: number }) {
  return (
    <div className="mt-6 text-left bg-[#0F172A] border border-[#334155] rounded-xl p-4 text-xs">
      <p className="text-[#64748B] mb-2">SHA-1 of your password, computed in this browser:</p>
      <p className="font-mono break-all text-sm">
        <span className="text-[#3B82F6] font-bold bg-[#3B82F6]/10 rounded px-0.5">{hash.slice(0, 5)}</span>
        <span className="text-[#475569]">{hash.slice(5)}</span>
      </p>
      <div className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-2 text-[#94A3B8]">
        <p>
          <span className="text-[#3B82F6] font-semibold">Sent:</span> only the first 5 characters
        </p>
        <p>
          <span className="text-[#10B981] font-semibold">Received:</span> {candidates.toLocaleString()} candidate hashes, matched locally
        </p>
      </div>
      <p className="mt-2 text-[#64748B]">Your password and its full hash never left this device (k-anonymity).</p>
    </div>
  );
}

function FoundResult({ count }: { count: number }) {
  const shown = useCountUp(count);
  const label = count >= 100_000 ? "Extremely common" : count >= 1_000 ? "Widely leaked" : "Leaked";
  return (
    <div className="animate-slide-up">
      <p className="text-xs uppercase tracking-widest text-[#EF4444] font-semibold">{label}</p>
      <p className="text-5xl md:text-6xl font-bold text-[#EF4444] my-3 tabular-nums">{shown.toLocaleString()}</p>
      <p className="text-[#F8FAFC] text-lg">
        times this exact password appears in real data breaches.
      </p>
      <p className="text-[#94A3B8] text-sm mt-3 max-w-lg mx-auto">
        Attackers try leaked lists first, so any account using it can be taken over <span className="text-[#EF4444] font-semibold">instantly</span>.
        If you reuse it, every one of those accounts falls together.
      </p>
    </div>
  );
}

function CleanResult({ crackTime }: { crackTime: string }) {
  return (
    <div className="animate-slide-up">
      <p className="text-xs uppercase tracking-widest text-[#10B981] font-semibold">Not found in known breaches</p>
      <p className="text-4xl font-bold text-[#10B981] my-3">0 leaks</p>
      <p className="text-[#94A3B8] text-sm max-w-lg mx-auto">
        Rough brute-force estimate: <span className="text-[#F8FAFC] font-semibold">{crackTime}</span> to crack at 10 billion guesses/sec.
        Not being leaked yet doesn&apos;t make it safe to reuse.
      </p>
    </div>
  );
}

export default function PasswordLeakCheck() {
  const [password, setPassword] = useState("");
  const [visible, setVisible] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState<Result | null>(null);

  const check = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!password) return;
    setLoading(true);
    setError("");
    setResult(null);
    try {
      const hash = await sha1Hex(password);
      const res = await fetch(`https://api.pwnedpasswords.com/range/${hash.slice(0, 5)}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const lines = (await res.text()).split("\n");
      const suffix = hash.slice(5);
      const match = lines.find((line) => line.slice(0, 35).toUpperCase() === suffix);
      const count = match ? parseInt(match.split(":")[1], 10) : 0;
      setResult(
        count > 0
          ? { status: "found", count, hash, candidates: lines.length }
          : { status: "clean", hash, candidates: lines.length, crackTime: estimateCrackTime(password) }
      );
    } catch {
      setError("Couldn't reach the breach database. Check your connection and try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6 md:p-8 w-full max-w-2xl mx-auto text-center">
      <h2 className="text-xl font-semibold mb-1">Has your password already leaked?</h2>
      <p className="text-sm text-[#94A3B8] mb-6">Checked against 900M+ real breached passwords. No signup. Nothing stored.</p>

      <form onSubmit={check} className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <input
            type={visible ? "text" : "password"}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Type any password"
            autoComplete="off"
            spellCheck={false}
            aria-label="Password to check"
            className="w-full px-4 py-3 pr-16 bg-[#0F172A] border border-[#334155] rounded-xl text-[#F8FAFC] placeholder-[#64748B] focus:outline-none focus:border-[#3B82F6]"
          />
          <button
            type="button"
            onClick={() => setVisible((v) => !v)}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-[#64748B] hover:text-[#F8FAFC]"
          >
            {visible ? "Hide" : "Show"}
          </button>
        </div>
        <button
          type="submit"
          disabled={!password || loading}
          className="px-6 py-3 bg-[#EF4444] hover:bg-[#DC2626] disabled:opacity-40 disabled:cursor-not-allowed text-white rounded-xl font-medium transition-all"
        >
          {loading ? "Checking..." : "Check leaks"}
        </button>
      </form>

      {error && <p className="mt-4 text-sm text-[#EF4444]">{error}</p>}

      {result && (
        <div className="mt-8" key={result.hash}>
          {result.status === "found" ? <FoundResult count={result.count} /> : <CleanResult crackTime={result.crackTime} />}
          <HashReveal hash={result.hash} candidates={result.candidates} />
        </div>
      )}
    </div>
  );
}
