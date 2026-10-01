"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import api from "@/lib/api";
import ScoreRing from "@/components/ScoreRing";
import StatCard from "@/components/StatCard";

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

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [fixes, setFixes] = useState<FixAction[]>([]);
  const [loading, setLoading] = useState(true);

  // Attack Cascade Simulation State
  const [isSimulating, setIsSimulating] = useState(false);
  const [cascadeStep, setCascadeStep] = useState(0);

  useEffect(() => {
    Promise.all([
      api.get("/dashboard/"),
      api.get("/dashboard/fixes"),
    ])
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

  const runCascadeSimulation = () => {
    setIsSimulating(true);
    setCascadeStep(1);
    setTimeout(() => setCascadeStep(2), 600);
    setTimeout(() => setCascadeStep(3), 1300);
    setTimeout(() => setCascadeStep(4), 2000);
  };

  const resetCascadeSimulation = () => {
    setIsSimulating(false);
    setCascadeStep(0);
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center h-96 gap-3">
        <div className="w-8 h-8 border-2 border-[#D4D6DC] border-t-transparent rounded-full animate-spin" />
        <span className="text-xs font-mono tracking-widest text-[#6B6E78] uppercase">
          SYNCHRONIZING ENCLAVE STATE...
        </span>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="text-center py-24 border border-dashed border-[#222429] rounded-lg p-8">
        <p className="text-sm font-mono text-[#A1A3AA]">No telemetry recorded yet.</p>
        <Link
          href="/accounts"
          className="mt-4 inline-block monolith-btn-primary"
        >
          ENROLL INITIAL ACCOUNTS
        </Link>
      </div>
    );
  }

  const riskColors: Record<string, string> = {
    critical: "#E54D2E",
    high: "#D97706",
    medium: "#D4D6DC",
    low: "#3E9B66",
  };

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Header telemetry band */}
      <div className="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-[#222429] gap-4">
        <div>
          <div className="flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#3E9B66]" />
            <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase font-display">
              ENCLAVE CONTROL // AIRSPACE VERIFIED
            </span>
          </div>
          <h1 className="text-2xl font-bold font-display tracking-tight text-[#F4F4F6] mt-1">
            Privacy Audit & Threat Matrix
          </h1>
          <p className="text-xs text-[#A1A3AA] mt-0.5">
            Continuous identity exposure, permission auditing, and attack cascade mitigation.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Link
            href="/breaches"
            className="monolith-btn-outline text-xs flex items-center gap-2"
          >
            <span className="w-2 h-2 rounded-full bg-[#E54D2E]" />
            SCAN BREACH DUMPS
          </Link>
          <Link
            href="/accounts"
            className="monolith-btn-primary text-xs"
          >
            + ADD ACCOUNT
          </Link>
        </div>
      </div>

      {/* Primary Gauge and Metrics */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        <div className="lg:col-span-1 bg-[#131417] border border-[#222429] rounded-lg p-6 flex flex-col items-center justify-center">
          <ScoreRing score={data.privacy_score} />
          <div className="w-full mt-4 pt-3 border-t border-[#1C1E24] flex items-center justify-between text-[11px] font-mono text-[#6B6E78]">
            <span>ENCLAVE: ACTIVE</span>
            <span className="text-[#3E9B66]">SELinux PASS</span>
          </div>
        </div>
        <div className="lg:col-span-3 grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
          <StatCard
            label="Monitored Vault"
            value={data.total_accounts}
            icon="@"
            color="#F4F4F6"
            subtitle={`${data.total_accounts} Active Nodes`}
          />
          <StatCard
            label="Exposed & Vulnerable"
            value={data.accounts_at_risk}
            icon="!"
            color="#E54D2E"
            subtitle="Risk Index >= 50"
          />
          <StatCard
            label="Verified Leaks"
            value={data.breaches_found}
            icon="B"
            color="#D97706"
            subtitle="Matched in dumps"
          />
          <StatCard
            label="Mitigations Completed"
            value={data.fixes_completed}
            icon="✓"
            color="#3E9B66"
            subtitle="Verified secure"
          />
          <StatCard
            label="Hardening Actions"
            value={data.fixes_pending}
            icon="?"
            color="#D4D6DC"
            subtitle="Pending execution"
          />
          <StatCard
            label="Vulnerability Spread"
            value={`${data.risk_distribution.critical || 0}C · ${data.risk_distribution.high || 0}H`}
            icon="#"
            color="#E54D2E"
            subtitle={`${data.risk_distribution.medium || 0} Med, ${data.risk_distribution.low || 0} Low`}
          />
        </div>
      </div>

      {/* Hackathon Shock Factor: Attack Cascade & Blast Radius Simulator */}
      <div className={`monolith-card p-6 transition-all ${isSimulating ? "border-[#E54D2E]/50 bg-[#161214]" : ""}`}>
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-4 border-b border-[#222429]">
          <div>
            <div className="flex items-center gap-2">
              <span className={`w-2 h-2 rounded-full ${isSimulating ? "bg-[#E54D2E] animate-pulse" : "bg-[#D4D6DC]"}`} />
              <h2 className="text-xs font-bold tracking-widest text-[#F4F4F6] uppercase font-display">
                ATTACK CASCADE & BLAST RADIUS SIMULATOR
              </h2>
            </div>
            <p className="text-xs text-[#A1A3AA] mt-1">
              Simulate domino credential stuff attack across linked identity nodes when a master email password leaks.
            </p>
          </div>
          <div className="flex items-center gap-2">
            {isSimulating && (
              <span className="text-[11px] font-mono text-[#E54D2E] px-2 py-1 bg-[#E54D2E]/10 rounded border border-[#E54D2E]/20">
                STEP {cascadeStep} / 4 EXECUTED
              </span>
            )}
            <button
              onClick={runCascadeSimulation}
              className="monolith-btn-primary text-xs"
            >
              {isSimulating ? "RE-RUN CASCADE" : "SIMULATE THREAT CASCADE"}
            </button>
            {isSimulating && (
              <button
                onClick={resetCascadeSimulation}
                className="monolith-btn-outline text-xs"
              >
                RESET
              </button>
            )}
          </div>
        </div>

        {/* Live Simulation Domino Steps */}
        {isSimulating ? (
          <div className="mt-5 grid grid-cols-1 md:grid-cols-4 gap-3 animate-slide-up">
            <div className={`p-4 rounded border transition-all ${cascadeStep >= 1 ? "bg-[#1B1214] border-[#E54D2E]/40" : "bg-[#131417] border-[#222429] opacity-40"}`}>
              <div className="text-[10px] font-mono text-[#E54D2E] font-bold">01 // INGESTION</div>
              <div className="text-xs font-bold text-[#F4F4F6] mt-1 font-display">Root Email Match</div>
              <p className="text-[11px] text-[#A1A3AA] mt-1">Primary credential harvested from paste site dump.</p>
            </div>
            <div className={`p-4 rounded border transition-all ${cascadeStep >= 2 ? "bg-[#1B1214] border-[#E54D2E]/40" : "bg-[#131417] border-[#222429] opacity-40"}`}>
              <div className="text-[10px] font-mono text-[#D97706] font-bold">02 // SPRAY</div>
              <div className="text-xs font-bold text-[#F4F4F6] mt-1 font-display">Credential Stuffing</div>
              <p className="text-[11px] text-[#A1A3AA] mt-1">Automated bot spray hits GitHub, AWS, and Netflix nodes.</p>
            </div>
            <div className={`p-4 rounded border transition-all ${cascadeStep >= 3 ? "bg-[#1B1214] border-[#E54D2E]/40" : "bg-[#131417] border-[#222429] opacity-40"}`}>
              <div className="text-[10px] font-mono text-[#D97706] font-bold">03 // PIVOT</div>
              <div className="text-xs font-bold text-[#F4F4F6] mt-1 font-display">Account Hijack</div>
              <p className="text-[11px] text-[#A1A3AA] mt-1">Password reset emails intercepted without 2FA challenge.</p>
            </div>
            <div className={`p-4 rounded border transition-all ${cascadeStep >= 4 ? "bg-[#251010] border-[#E54D2E]" : "bg-[#131417] border-[#222429] opacity-40"}`}>
              <div className="text-[10px] font-mono text-[#E54D2E] font-bold">04 // COLLATERAL</div>
              <div className="text-xs font-bold text-[#E54D2E] mt-1 font-display">Blast Radius: 78%</div>
              <p className="text-[11px] text-[#F4F4F6] mt-1">Critical financial & developer identities compromised.</p>
            </div>
          </div>
        ) : (
          <div className="mt-4 p-4 rounded bg-[#0B0C0E] border border-[#222429] flex flex-col md:flex-row items-center justify-between text-xs text-[#A1A3AA] gap-3">
            <div className="flex items-center gap-3">
              <span className="w-1.5 h-1.5 rounded-full bg-[#D4D6DC]" />
              <span>Simulates the real-world Domino Effect: single password reuse causing multi-account collateral breaches.</span>
            </div>
            <span className="font-mono text-[11px] text-[#6B6E78]">CLICK &apos;SIMULATE THREAT CASCADE&apos; TO DEMO</span>
          </div>
        )}
      </div>

      {/* Hardware Protection Enclave Card */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="monolith-card p-6 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase font-display">
                ANDROID RUNTIME SENTRY
              </span>
              <span className="text-[10px] font-mono text-[#3E9B66] bg-[#3E9B66]/10 px-2 py-0.5 rounded border border-[#3E9B66]/20">
                ACTIVE
              </span>
            </div>
            <h3 className="text-base font-bold font-display text-[#F4F4F6] mt-2">
              Endpoint Permissions & Anti-Theft Guard
            </h3>
            <p className="text-xs text-[#A1A3AA] mt-1">
              Continuous audit of Accessibility trojans, tapjacking overlays, background surveillance, and desk motion sentry.
            </p>
          </div>
          <div className="mt-4 pt-4 border-t border-[#1C1E24] flex items-center justify-between">
            <span className="text-[11px] font-mono text-[#6B6E78]">6 SENSITIVE PERMISSIONS MONITORED</span>
            <span className="text-xs font-display font-bold text-[#F4F4F6]">HARDENED</span>
          </div>
        </div>

        <div className="monolith-card p-6 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase font-display">
                AIRSPACE RF SENSORS
              </span>
              <span className="text-[10px] font-mono text-[#D4D6DC] bg-[#D4D6DC]/10 px-2 py-0.5 rounded border border-[#D4D6DC]/20">
                READY
              </span>
            </div>
            <h3 className="text-base font-bold font-display text-[#F4F4F6] mt-2">
              Physical RF & Rogue AP Radar
            </h3>
            <p className="text-xs text-[#A1A3AA] mt-1">
              Real-time matrix scanning for Evil-Twin access points, deauthentication attacks, and unauthorized BLE trackers.
            </p>
          </div>
          <div className="mt-4 pt-4 border-t border-[#1C1E24] flex items-center justify-between">
            <span className="text-[11px] font-mono text-[#6B6E78]">AIRSPACE SCANNER CONNECTED</span>
            <span className="text-xs font-display font-bold text-[#F4F4F6]">ZERO DETECTED</span>
          </div>
        </div>
      </div>

      {/* Single Points of Failure */}
      {data.single_points_of_failure.length > 0 && (
        <div className="monolith-card p-6 border-[#E54D2E]/40">
          <div className="flex items-center justify-between mb-3">
            <div>
              <h2 className="text-xs font-bold tracking-widest text-[#E54D2E] uppercase font-display">
                CRITICAL VULNERABILITY: SINGLE POINTS OF FAILURE (SPOF)
              </h2>
              <p className="text-xs text-[#A1A3AA] mt-1">
                These nodes link directly into 3+ downstream services without isolated credentials.
              </p>
            </div>
            <span className="text-[10px] font-mono text-[#E54D2E] px-2 py-1 rounded bg-[#E54D2E]/10 border border-[#E54D2E]/20">
              {data.single_points_of_failure.length} IDENTIFIED
            </span>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mt-4">
            {data.single_points_of_failure.map((a) => (
              <div key={a.id} className="bg-[#0B0C0E] border border-[#222429] rounded p-4 flex flex-col justify-between">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold font-display text-[#F4F4F6]">{a.service_name}</span>
                  <span className="text-[10px] font-mono text-[#E54D2E] px-1.5 py-0.5 rounded bg-[#E54D2E]/10 border border-[#E54D2E]/20">
                    {a.risk_score.toFixed(0)} PTS
                  </span>
                </div>
                <div className="mt-3 text-[11px] font-mono text-[#6B6E78] uppercase">
                  CATEGORY: {a.category}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Distribution & Categories */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="monolith-card p-6">
          <h2 className="text-xs font-bold tracking-widest text-[#6B6E78] uppercase font-display mb-4">
            RISK EXPOSURE DISTRIBUTION
          </h2>
          <div className="space-y-3.5">
            {Object.entries(data.risk_distribution).map(([level, count]) => (
              <div key={level} className="space-y-1">
                <div className="flex items-center justify-between text-xs font-mono">
                  <div className="flex items-center gap-2">
                    <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: riskColors[level] }} />
                    <span className="text-[#A1A3AA] uppercase">{level}</span>
                  </div>
                  <span className="font-bold text-[#F4F4F6]">{count} NODES</span>
                </div>
                <div className="w-full bg-[#0B0C0E] rounded-full h-1.5 overflow-hidden">
                  <div
                    className="h-full transition-all duration-700 rounded-full"
                    style={{
                      width: `${data.total_accounts ? (count / data.total_accounts) * 100 : 0}%`,
                      backgroundColor: riskColors[level],
                    }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="monolith-card p-6">
          <h2 className="text-xs font-bold tracking-widest text-[#6B6E78] uppercase font-display mb-4">
            CATEGORY INVENTORY BREAKDOWN
          </h2>
          <div className="space-y-2">
            {Object.entries(data.category_breakdown).map(([cat, count]) => (
              <div key={cat} className="flex items-center justify-between px-3 py-2 rounded bg-[#0B0C0E] border border-[#222429]">
                <span className="text-xs font-display tracking-wide uppercase text-[#A1A3AA]">{cat}</span>
                <span className="text-xs font-mono font-bold text-[#F4F4F6]">{count}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Hardening Checklist */}
      <div className="monolith-card p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-xs font-bold tracking-widest text-[#6B6E78] uppercase font-display">
              HARDENING CHECKLIST & REMEDIATION
            </h2>
            <p className="text-xs text-[#A1A3AA] mt-0.5">
              Ranked algorithmic actions to lower identity exposure and break attack cascades.
            </p>
          </div>
          <span className="text-[10px] font-mono text-[#D4D6DC]">
            {fixes.filter((f) => f.status === "completed").length} / {fixes.length} COMPLETED
          </span>
        </div>

        <div className="space-y-2.5">
          {fixes.slice(0, 8).map((fix) => {
            const isDone = fix.status === "completed";
            return (
              <div
                key={fix.id}
                className={`flex items-center justify-between p-3.5 rounded border transition-all ${
                  isDone
                    ? "bg-[#0B0C0E] border-[#222429] opacity-60"
                    : "bg-[#0B0C0E] border-[#222429] hover:border-[#383B43]"
                }`}
              >
                <div className="flex items-center gap-3 min-w-0">
                  <button
                    onClick={() => !isDone && completeFix(fix.id)}
                    className={`w-4 h-4 rounded border flex items-center justify-center transition-colors flex-shrink-0 ${
                      isDone
                        ? "bg-[#3E9B66] border-[#3E9B66]"
                        : "border-[#4A4D57] hover:border-[#F4F4F6]"
                    }`}
                  >
                    {isDone && <span className="text-[9px] text-[#0B0C0E] font-bold">✓</span>}
                  </button>
                  <div className="min-w-0">
                    <p className={`text-xs font-display tracking-wide ${isDone ? "line-through text-[#6B6E78]" : "text-[#F4F4F6]"}`}>
                      {fix.description}
                    </p>
                    <div className="flex items-center gap-2 mt-0.5 text-[10px] font-mono text-[#6B6E78]">
                      <span className="text-[#3E9B66] font-bold">
                        -{fix.risk_reduction.toFixed(0)} PTS REDUCTION
                      </span>
                      <span>·</span>
                      <span className="uppercase">{fix.action_type.replace(/_/g, " ")}</span>
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <span className="text-[10px] font-mono text-[#6B6E78] px-2 py-0.5 rounded border border-[#222429]">
                    P{fix.priority}
                  </span>
                  {!isDone && (
                    <button
                      onClick={() => completeFix(fix.id)}
                      className="monolith-btn-outline text-[11px] py-1 px-2.5"
                    >
                      RESOLVE
                    </button>
                  )}
                </div>
              </div>
            );
          })}
          {fixes.length === 0 && (
            <p className="text-center text-xs font-mono text-[#6B6E78] py-8">
              No pending remediation tasks. All active nodes hardened.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
