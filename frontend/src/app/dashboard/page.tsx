"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { Chip, Empty, Headline, Row, SectionTitle, Spinner, StatGrid, StatTile, riskTone } from "@/components/editorial";

interface DashboardData {
  privacy_score: number;
  total_accounts: number;
  accounts_at_risk: number;
  breaches_found: number;
  fixes_completed: number;
  fixes_pending: number;
  risk_distribution: Record<string, number>;
  category_breakdown: Record<string, number>;
  single_points_of_failure: Array<{ id: number; service_name: string; risk_score: number; category: string }>;
}

interface FixAction {
  id: number;
  action_type: string;
  description: string;
  priority: number;
  risk_reduction: number;
  status: string;
}

const LEVELS = ["critical", "high", "medium", "low"] as const;
const LEVEL_BAR: Record<string, string> = { critical: "bg-signal", high: "bg-warn", medium: "bg-ink-2", low: "bg-ok" };

function headline(d: DashboardData): { lead: string; rest: string } {
  if (d.total_accounts === 0) return { lead: "Nothing on file yet.", rest: "Add the accounts you use to start the audit." };
  const hub = d.single_points_of_failure[0];
  if (hub) return { lead: hub.service_name, rest: "is a single point of failure: one break-in there reaches your other accounts." };
  if (d.breaches_found > 0) {
    return { lead: `${d.breaches_found} ${d.breaches_found === 1 ? "breach" : "breaches"}`, rest: "touch the accounts you use." };
  }
  if (d.accounts_at_risk > 0) {
    return { lead: `${d.accounts_at_risk} of your ${d.total_accounts} accounts`, rest: "are at serious risk." };
  }
  return { lead: "No account", rest: "is at serious risk right now." };
}

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [fixes, setFixes] = useState<FixAction[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([api.get("/dashboard/"), api.get("/dashboard/fixes")])
      .then(([dashRes, fixRes]) => {
        setData(dashRes.data);
        setFixes(fixRes.data);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const completeFix = async (fixId: number) => {
    await api.patch(`/dashboard/fixes/${fixId}/complete`);
    setFixes((prev) => prev.map((f) => (f.id === fixId ? { ...f, status: "completed" } : f)));
  };

  if (loading) return <Spinner />;
  if (!data) return <Empty>Couldn&apos;t load your overview. Check that the backend is running.</Empty>;

  const { lead, rest } = headline(data);
  const pending = fixes.filter((f) => f.status !== "completed");
  const done = fixes.length - pending.length;

  return (
    <div className="space-y-14">
      <Headline
        eyebrow="Audit · 01 · Overview"
        lead={lead}
        rest={rest}
        sub={`Privacy score ${data.privacy_score}/100 · ${data.total_accounts} accounts on file · ${pending.length} fixes waiting`}
      />

      <StatGrid>
        <StatTile value={data.privacy_score} label="Privacy score" active />
        <StatTile value={data.total_accounts} label="Accounts" href="/accounts" />
        <StatTile value={data.accounts_at_risk} label="At risk" dim={!data.accounts_at_risk} href="/accounts" />
        <StatTile value={data.breaches_found} label="Breaches" dim={!data.breaches_found} href="/breaches" />
        <StatTile value={pending.length} label="Fixes waiting" dim={!pending.length} />
        <StatTile value={done} label="Fixes done" dim={!done} />
      </StatGrid>

      {data.single_points_of_failure.length > 0 && (
        <section>
          <SectionTitle title="Single points of failure" meta={`${data.single_points_of_failure.length} found`} />
          {data.single_points_of_failure.map((a, i) => (
            <Row
              key={a.id}
              lead={<span className={`num text-3xl ${riskTone(a.risk_score)}`}>{a.risk_score.toFixed(0)}</span>}
              title={a.service_name}
              meta={a.category}
              note={i === 0 ? "Connects to three or more of your accounts. Lock this one down first." : "Connects to three or more of your accounts."}
              noteTone={i === 0 ? "warn" : "default"}
            />
          ))}
        </section>
      )}

      <section>
        <SectionTitle title="Fix checklist" meta="Ranked by risk removed" />
        {fixes.slice(0, 10).map((fix) => {
          const completed = fix.status === "completed";
          return (
            <Row
              key={fix.id}
              muted={completed}
              lead={<span className="num text-3xl text-ok">&minus;{fix.risk_reduction.toFixed(0)}</span>}
              title={<span className={completed ? "line-through" : ""}>{fix.description}</span>}
              chips={
                <>
                  <Chip>{fix.action_type.replace(/_/g, " ")}</Chip>
                  <Chip tone={fix.priority >= 80 ? "warn" : "default"}>Priority {fix.priority}</Chip>
                </>
              }
              aside={
                completed ? (
                  <span className="eyebrow text-ok">Done</span>
                ) : (
                  <button
                    onClick={() => completeFix(fix.id)}
                    className="text-sm px-3 py-1.5 border border-ink rounded-sm hover:bg-ink hover:text-card transition-colors"
                  >
                    Mark done
                  </button>
                )
              }
            />
          );
        })}
        {fixes.length === 0 && <Empty>No fixes needed yet. Add accounts to generate recommendations.</Empty>}
      </section>

      <div className="grid lg:grid-cols-2 gap-14">
        <section>
          <SectionTitle title="Risk distribution" meta={`${data.total_accounts} accounts`} />
          {LEVELS.map((level) => {
            const count = data.risk_distribution[level] || 0;
            const pct = data.total_accounts ? (count / data.total_accounts) * 100 : 0;
            return (
              <div key={level} className="flex items-center gap-4 py-3 border-b border-rule">
                <span className="eyebrow w-20">{level}</span>
                <div className="flex-1 h-2 bg-rule/60">
                  <div className={`h-2 ${LEVEL_BAR[level]} transition-all duration-700`} style={{ width: `${pct}%` }} />
                </div>
                <span className="num text-2xl w-8 text-right">{count}</span>
              </div>
            );
          })}
        </section>

        <section>
          <SectionTitle title="Categories" meta={`${Object.keys(data.category_breakdown).length} kinds`} />
          {Object.entries(data.category_breakdown)
            .sort((a, b) => b[1] - a[1])
            .map(([cat, count]) => (
              <div key={cat} className="flex items-center justify-between py-3 border-b border-rule">
                <span className="capitalize">{cat}</span>
                <span className="num text-2xl">{count}</span>
              </div>
            ))}
        </section>
      </div>
    </div>
  );
}
