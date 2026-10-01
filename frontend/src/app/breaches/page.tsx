"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { Chip, Empty, Headline, Row, SectionTitle, StatGrid, StatTile, riskTone } from "@/components/editorial";

interface BreachRecord {
  id: number;
  account_name: string;
  breach_name: string;
  breach_date: string | null;
  data_exposed: string[];
  source: string;
}

interface Unlisted {
  name: string;
  domain: string;
  email: string;
  date: string | null;
  data: string[];
}

interface ScanResult {
  total_accounts_scanned: number;
  affected_accounts: number;
  total_breaches_found: number;
  confirmed_account_breaches: number;
  unlisted_exposures: Unlisted[];
  sources: { catalog: string | null; email: string | null };
  errors: string[];
}

interface Prediction {
  service: string;
  probability_6_months: number;
  risk_level: string;
  factors: Record<string, number>;
  recommendation: string;
}

const CONFIRMED = new Set(["hibp_account", "xposedornot"]);

export default function BreachesPage() {
  const [scanning, setScanning] = useState(false);
  const [scan, setScan] = useState<ScanResult | null>(null);
  const [history, setHistory] = useState<BreachRecord[]>([]);
  const [predictions, setPredictions] = useState<Prediction[]>([]);

  useEffect(() => {
    api.get("/breaches/history").then((r) => setHistory(r.data)).catch(() => {});
    api.get("/ai/breach-predictions").then((r) => setPredictions(r.data)).catch(() => {});
  }, []);

  const runScan = async () => {
    setScanning(true);
    try {
      const res = await api.post("/breaches/scan-all");
      setScan(res.data);
      const [hist, pred] = await Promise.all([api.get("/breaches/history"), api.get("/ai/breach-predictions")]);
      setHistory(hist.data);
      setPredictions(pred.data);
    } catch {}
    setScanning(false);
  };

  const confirmed = history.filter((b) => CONFIRMED.has(b.source));
  const serviceLevel = history.length - confirmed.length;
  const affected = new Set(history.map((b) => b.account_name)).size;
  const unlisted = scan?.unlisted_exposures ?? [];

  const head =
    confirmed.length > 0
      ? { lead: `Your email is in ${confirmed.length} leaked ${confirmed.length === 1 ? "dataset" : "datasets"}.`, rest: "Change those passwords before anything else." }
      : history.length > 0
        ? { lead: `${affected} ${affected === 1 ? "service" : "services"} you use`, rest: "have been breached. Your own email isn't confirmed in the leaks yet." }
        : { lead: "No known breaches", rest: "touch your accounts yet. Run a scan to check against live breach data." };

  return (
    <div className="space-y-14">
      <div className="flex items-start justify-between gap-6">
        <Headline
          eyebrow="Audit · 04 · Breaches"
          lead={head.lead}
          rest={head.rest}
          sub="Checked against Have I Been Pwned's public breach catalog and per-email lookups."
        />
        <button
          onClick={runScan}
          disabled={scanning}
          className="shrink-0 mt-8 px-6 py-3 bg-ink hover:bg-signal disabled:opacity-40 text-card rounded-sm font-medium transition-colors"
        >
          {scanning ? "Scanning…" : "Run full scan"}
        </button>
      </div>

      <StatGrid cols={5}>
        <StatTile value={history.length} label="Breach records" dim={!history.length} />
        <StatTile value={confirmed.length} label="Your email leaked" dim={!confirmed.length} active={confirmed.length > 0} />
        <StatTile value={serviceLevel} label="Service breached" dim={!serviceLevel} />
        <StatTile value={affected} label="Accounts affected" dim={!affected} />
        <StatTile value={unlisted.length} label="Unlisted exposures" dim={!unlisted.length} />
      </StatGrid>

      {scan && (
        <p className="text-sm text-ink-2 -mt-8">
          Scanned {scan.total_accounts_scanned} accounts · catalog {scan.sources.catalog ? "Have I Been Pwned" : "unavailable"} · email lookups{" "}
          {scan.sources.email === "hibp" ? "Have I Been Pwned" : scan.sources.email === "xposedornot" ? "XposedOrNot" : "unavailable"}
          {scan.errors.map((e) => (
            <span key={e} className="block text-signal mt-1">{e}</span>
          ))}
        </p>
      )}

      {unlisted.length > 0 && (
        <section>
          <SectionTitle title="Breaches on services you haven't listed" meta={`${unlisted.length} found`} />
          {unlisted.map((u) => (
            <Row
              key={`${u.email}-${u.name}`}
              lead={<span className="num text-3xl text-signal">{u.date ? u.date.slice(0, 4) : "—"}</span>}
              title={u.name}
              meta={[u.domain, u.email].filter(Boolean).join(" · ")}
              chips={u.data.map((d) => <Chip key={d} tone="muted">{d}</Chip>)}
              note="Your email is in this breach but the service isn't in your inventory. Add it and change its password."
              noteTone="warn"
            />
          ))}
        </section>
      )}

      <section>
        <SectionTitle title="Breach history" meta={`${history.length} records`} />
        {history.map((b) => {
          const isConfirmed = CONFIRMED.has(b.source);
          return (
            <Row
              key={b.id}
              lead={<span className={`num text-3xl ${isConfirmed ? "text-signal" : "text-ink-3"}`}>{b.breach_date ? b.breach_date.slice(0, 4) : "—"}</span>}
              title={b.breach_name}
              meta={`on your ${b.account_name} account`}
              chips={b.data_exposed.map((d) => (
                <Chip key={d} tone={/password/i.test(d) ? "warn" : "muted"}>{d}</Chip>
              ))}
              note={isConfirmed ? "Your email address is in the leaked data." : "The service was breached; your account isn't confirmed in the leak."}
              noteTone={isConfirmed ? "warn" : "default"}
            />
          );
        })}
        {history.length === 0 && <Empty>No breach records yet. Run a full scan.</Empty>}
      </section>

      <section>
        <SectionTitle title="Six-month risk outlook" meta="Heuristic estimate" />
        <p className="text-sm text-ink-3 py-3 border-b border-rule">
          Estimated from each account&apos;s category, breach history, 2FA and password reuse. A rule of thumb, not a prediction model.
        </p>
        {predictions.map((p) => (
          <Row
            key={p.service}
            lead={<span className={`num text-3xl ${riskTone(p.probability_6_months)}`}>{Math.round(p.probability_6_months)}%</span>}
            title={p.service}
            chips={Object.entries(p.factors)
              .filter(([, v]) => v > 0)
              .map(([k, v]) => (
                <Chip key={k} tone="muted">{k.replace(/_/g, " ")} +{v}</Chip>
              ))}
            note={p.recommendation}
          />
        ))}
        {predictions.length === 0 && <Empty>Add accounts to see an outlook.</Empty>}
      </section>
    </div>
  );
}
