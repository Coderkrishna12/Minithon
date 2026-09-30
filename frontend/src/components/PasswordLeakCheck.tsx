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
    <div className="mt-8 pt-5 border-t border-dashed border-rule-strong">
      <p className="eyebrow">Chain of custody</p>
      <p className="mt-3 font-mono text-[0.8rem] break-all leading-relaxed">
        <span className="bg-ink text-card px-1 py-0.5">{hash.slice(0, 5)}</span>
        <span className="text-rule-strong">{hash.slice(5)}</span>
      </p>
      <dl className="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
        <div>
          <dt className="eyebrow text-ink">Sent</dt>
          <dd className="text-ink-2 mt-1">The first 5 characters of the SHA-1 hash.</dd>
        </div>
        <div>
          <dt className="eyebrow text-ink">Received</dt>
          <dd className="text-ink-2 mt-1">{candidates.toLocaleString()} candidate hashes, matched on this device.</dd>
        </div>
      </dl>
    </div>
  );
}

function FoundResult({ count }: { count: number }) {
  const shown = useCountUp(count);
  const label = count >= 100_000 ? "Extremely common" : count >= 1_000 ? "Widely leaked" : "Leaked";
  return (
    <div className="relative">
      <span className="stamp absolute right-0 -top-2 text-signal text-sm">Leaked</span>
      <p className="eyebrow text-signal">{label}</p>
      <p className="num text-signal text-[4.2rem] md:text-[5.2rem] leading-none mt-3">{shown.toLocaleString()}</p>
      <p className="mt-3 text-lg leading-snug">times this exact password appears in real data breaches.</p>
      <p className="mt-3 text-sm text-ink-2 leading-relaxed">
        Attackers try leaked lists first, so any account using it can be taken over{" "}
        <span className="text-signal font-medium">instantly</span>. If you reuse it, every one of those accounts falls
        together.
      </p>
    </div>
  );
}

function CleanResult({ crackTime }: { crackTime: string }) {
  return (
    <div className="relative">
      <span className="stamp absolute right-0 -top-2 text-ok text-sm">Not found</span>
      <p className="eyebrow text-ok">No known breach</p>
      <p className="num text-ok text-[4.2rem] leading-none mt-3">0</p>
      <p className="mt-3 text-lg leading-snug">appearances in known data breaches.</p>
      <p className="mt-3 text-sm text-ink-2 leading-relaxed">
        Rough brute-force estimate: <span className="text-ink font-medium">{crackTime}</span> at 10 billion
        guesses/sec. Not being leaked yet doesn&apos;t make it safe to reuse.
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
    <div className="bg-card border border-rule rounded-sm shadow-[0_1px_0_#DCD4C4,0_18px_40px_-24px_rgba(23,21,15,0.35)] w-full text-left">
      <div className="flex items-center justify-between px-6 md:px-8 py-3 border-b border-rule">
        <p className="eyebrow">Exhibit A &middot; Password</p>
        <p className="eyebrow">k-anonymous</p>
      </div>

      <div className="px-6 md:px-8 pt-6 pb-8">
        <h2 className="text-[2rem] leading-tight">Has your password already leaked?</h2>
        <p className="mt-2 text-sm text-ink-2">Checked against 900M+ real breached passwords. No signup. Nothing stored.</p>

        <form onSubmit={check} className="mt-6">
          <div className="flex items-end gap-3 border-b-2 border-ink focus-within:border-signal transition-colors">
            <input
              type={visible ? "text" : "password"}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Type any password"
              autoComplete="off"
              spellCheck={false}
              aria-label="Password to check"
              className="flex-1 min-w-0 bg-transparent py-3 font-mono text-lg text-ink placeholder:text-ink-3 placeholder:font-sans placeholder:text-base focus:outline-none"
            />
            <button
              type="button"
              onClick={() => setVisible((v) => !v)}
              className="eyebrow pb-4 hover:text-ink transition-colors"
            >
              {visible ? "Hide" : "Show"}
            </button>
          </div>
          <button
            type="submit"
            disabled={!password || loading}
            className="mt-5 w-full sm:w-auto px-6 py-3 bg-ink text-card rounded-sm hover:bg-signal disabled:opacity-30 disabled:hover:bg-ink disabled:cursor-not-allowed transition-colors"
          >
            {loading ? "Checking…" : "Check leaks"}
          </button>
        </form>

        {error && <p className="mt-4 text-sm text-signal">{error}</p>}

        {result && (
          <div className="mt-10 animate-slide-up" key={result.hash}>
            {result.status === "found" ? <FoundResult count={result.count} /> : <CleanResult crackTime={result.crackTime} />}
            <HashReveal hash={result.hash} candidates={result.candidates} />
          </div>
        )}
      </div>
    </div>
  );
}
