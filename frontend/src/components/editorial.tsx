import Link from "next/link";
import type { ReactNode } from "react";

export type Tone = "default" | "warn" | "ok" | "muted";

export function riskTone(score: number): string {
  if (score >= 50) return "text-signal";
  if (score >= 25) return "text-warn";
  return "text-ok";
}

export function Headline({ eyebrow, lead, rest, sub }: { eyebrow: string; lead: string; rest: string; sub?: ReactNode }) {
  return (
    <header className="animate-slide-up">
      <p className="eyebrow">{eyebrow}</p>
      <h1 className="mt-4 text-[2.6rem] md:text-[3.4rem] leading-[1.02] max-w-4xl">
        <span className="text-signal">{lead}</span> {rest}
      </h1>
      {sub && <p className="mt-4 text-sm text-ink-2">{sub}</p>}
    </header>
  );
}

export function StatGrid({ children, cols = 6 }: { children: ReactNode; cols?: 3 | 4 | 5 | 6 }) {
  const lg = { 3: "lg:grid-cols-3", 4: "lg:grid-cols-4", 5: "lg:grid-cols-5", 6: "lg:grid-cols-6" }[cols];
  return <div className={`grid grid-cols-2 md:grid-cols-3 ${lg} gap-2`}>{children}</div>;
}

export function StatTile({
  value,
  label,
  active = false,
  dim = false,
  href,
  onClick,
}: {
  value: ReactNode;
  label: string;
  active?: boolean;
  dim?: boolean;
  href?: string;
  onClick?: () => void;
}) {
  const body = (
    <>
      <span className={`num text-[2.9rem] leading-none ${active ? "text-card" : dim ? "text-ink-3" : "text-ink"}`}>{value}</span>
      <span className={`eyebrow ${active ? "text-rule-strong" : ""}`}>{label}</span>
    </>
  );
  const className = `flex flex-col justify-between gap-6 min-h-[8.5rem] p-4 rounded-sm border text-left transition-colors ${
    active ? "bg-ink border-ink" : "bg-card border-rule hover:border-ink"
  }`;
  if (href) return <Link href={href} className={className}>{body}</Link>;
  if (onClick) return <button type="button" onClick={onClick} className={className}>{body}</button>;
  return <div className={className.replace(" hover:border-ink", "")}>{body}</div>;
}

export function SectionTitle({ title, meta, action }: { title: string; meta?: ReactNode; action?: ReactNode }) {
  return (
    <div className="flex items-end justify-between gap-4 border-b border-ink pb-2 mb-1">
      <h2 className="section-title">{title}</h2>
      <div className="flex items-center gap-4">
        {meta !== undefined && <span className="eyebrow">{meta}</span>}
        {action}
      </div>
    </div>
  );
}

export function Chip({ children, tone = "default" }: { children: ReactNode; tone?: Tone }) {
  const tones: Record<Tone, string> = {
    default: "border-rule-strong text-ink-2",
    warn: "border-signal text-signal",
    ok: "border-ok text-ok",
    muted: "border-rule text-ink-3",
  };
  return (
    <span className={`inline-block border rounded-[2px] px-1.5 py-[1px] font-mono text-[0.62rem] uppercase tracking-[0.12em] ${tones[tone]}`}>
      {children}
    </span>
  );
}

export function Row({
  lead,
  title,
  meta,
  chips,
  note,
  noteTone = "default",
  aside,
  muted = false,
}: {
  lead?: ReactNode;
  title: ReactNode;
  meta?: ReactNode;
  chips?: ReactNode;
  note?: ReactNode;
  noteTone?: Tone;
  aside?: ReactNode;
  muted?: boolean;
}) {
  const noteColor = { default: "text-ink-2", warn: "text-signal", ok: "text-ok", muted: "text-ink-3" }[noteTone];
  return (
    <div className={`group flex items-start gap-5 py-4 border-b border-rule ${muted ? "opacity-55" : ""}`}>
      {lead !== undefined && <div className="w-14 shrink-0 pt-0.5">{lead}</div>}
      <div className="flex-1 min-w-0">
        <div className="flex items-baseline gap-3 flex-wrap">
          <span className="font-medium">{title}</span>
          {meta && <span className="text-sm text-ink-3">{meta}</span>}
        </div>
        {chips && <div className="flex flex-wrap gap-1.5 mt-2">{chips}</div>}
        {note && <p className={`text-sm mt-2 ${noteColor}`}>{note}</p>}
      </div>
      {aside && <div className="shrink-0 self-center">{aside}</div>}
    </div>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="py-10 text-ink-3">{children}</p>;
}

export function Spinner() {
  return (
    <div className="flex items-center justify-center h-96">
      <p className="eyebrow animate-pulse">Reading your file&hellip;</p>
    </div>
  );
}
