"use client";

import { useState } from "react";
import api from "@/lib/api";

interface BreachRecord {
  id: number;
  account_name: string;
  breach_name: string;
  breach_date: string | null;
  data_exposed: string[];
  source: string;
}

interface Prediction {
  service: string;
  probability_6_months: number;
  risk_level: string;
  factors: Record<string, number>;
  recommendation: string;
}

export default function BreachesPage() {
  const [scanning, setScanning] = useState(false);
  const [scanResult, setScanResult] = useState<{
    total_accounts_scanned: number;
    affected_accounts: number;
    total_breaches_found: number;
  } | null>(null);
  const [history, setHistory] = useState<BreachRecord[]>([]);
  const [predictions, setPredictions] = useState<Prediction[]>([]);
  const [activeTab, setActiveTab] = useState<"scan" | "history" | "predict">("scan");

  const runScan = async () => {
    setScanning(true);
    try {
      const res = await api.post("/breaches/scan-all");
      setScanResult(res.data);
      const histRes = await api.get("/breaches/history");
      setHistory(histRes.data);
    } catch {}
    setScanning(false);
  };

  const loadPredictions = async () => {
    try {
      const res = await api.get("/ai/breach-predictions");
      setPredictions(res.data);
    } catch {}
  };

  const riskColors: Record<string, string> = {
    critical: "#E54D2E",
    high: "#D97706",
    medium: "#D4D6DC",
    low: "#3E9B66",
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-[#222429] gap-4">
        <div>
          <div className="flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-[#E54D2E]" />
            <span className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase font-display">
              LEAK RECONNAISSANCE // HIBP & DARK WEB DUMPS
            </span>
          </div>
          <h1 className="text-2xl font-bold font-display tracking-tight text-[#F4F4F6] mt-1">
            Breach Intelligence & Predictive Radar
          </h1>
          <p className="text-xs text-[#A1A3AA] mt-0.5">
            Audit known external paste dumps, dark web databases, and calculate machine-learned compromise probabilities.
          </p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-2 border-b border-[#222429] pb-3">
        {(["scan", "history", "predict"] as const).map((tab) => {
          const isActive = activeTab === tab;
          return (
            <button
              key={tab}
              onClick={() => {
                setActiveTab(tab);
                if (tab === "history" && history.length === 0) {
                  api.get("/breaches/history").then((r) => setHistory(r.data)).catch(() => {});
                }
                if (tab === "predict" && predictions.length === 0) loadPredictions();
              }}
              className={`px-3.5 py-1.5 rounded text-xs font-mono tracking-wider uppercase transition-all ${
                isActive
                  ? "bg-[#18191E] text-[#F4F4F6] border border-[#2B2E36]"
                  : "text-[#6B6E78] hover:text-[#A1A3AA] border border-transparent"
              }`}
            >
              {tab === "scan" ? "01 // LIVE RECON" : tab === "history" ? `02 // INCIDENT ARCHIVE (${history.length})` : "03 // ML PREDICTIONS"}
            </button>
          );
        })}
      </div>

      {/* Tab 1: Live Recon Scan */}
      {activeTab === "scan" && (
        <div className="space-y-6">
          <div className="monolith-card p-8 text-center flex flex-col items-center">
            <div className="w-12 h-12 rounded border border-[#222429] bg-[#0B0C0E] flex items-center justify-center mb-4">
              <svg className="w-6 h-6 text-[#E54D2E]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            </div>
            <h2 className="text-sm font-bold tracking-widest text-[#F4F4F6] uppercase font-display mb-2">
              DATABASE LEAK RECONNAISSANCE SCAN
            </h2>
            <p className="text-xs text-[#A1A3AA] mb-6 max-w-md">
              Validates all monitored identities and service credentials against verified external breaches and pastebin disclosures.
            </p>
            <button
              onClick={runScan}
              disabled={scanning}
              className="monolith-btn-primary px-8 py-3 disabled:opacity-50"
            >
              {scanning ? "AUDITING PUBLIC DUMPS..." : "INITIATE RECON SCAN"}
            </button>
          </div>

          {scanResult && (
            <div className="monolith-card p-6 animate-slide-up">
              <h3 className="text-xs font-bold tracking-widest text-[#6B6E78] uppercase font-display mb-4">
                RECON SCAN OUTCOME
              </h3>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="bg-[#0B0C0E] border border-[#222429] rounded p-4 text-center">
                  <div className="text-3xl font-black font-display text-[#F4F4F6]">{scanResult.total_accounts_scanned}</div>
                  <div className="text-[10px] font-mono tracking-widest text-[#6B6E78] uppercase mt-1">NODES AUDITED</div>
                </div>
                <div className="bg-[#0B0C0E] border border-[#222429] rounded p-4 text-center">
                  <div className="text-3xl font-black font-display text-[#E54D2E]">{scanResult.affected_accounts}</div>
                  <div className="text-[10px] font-mono tracking-widest text-[#E54D2E] uppercase mt-1">IDENTITIES COMPROMISED</div>
                </div>
                <div className="bg-[#0B0C0E] border border-[#222429] rounded p-4 text-center">
                  <div className="text-3xl font-black font-display text-[#D97706]">{scanResult.total_breaches_found}</div>
                  <div className="text-[10px] font-mono tracking-widest text-[#D97706] uppercase mt-1">VERIFIED LEAK OCCURRENCES</div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Tab 2: Breach History */}
      {activeTab === "history" && (
        <div className="space-y-3">
          {history.map((b) => (
            <div key={b.id} className="monolith-card p-4 flex items-start gap-4">
              <div className="w-8 h-8 rounded border border-[#E54D2E]/30 bg-[#E54D2E]/10 flex items-center justify-center flex-shrink-0 text-xs font-mono text-[#E54D2E]">
                !
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold font-display text-[#F4F4F6]">{b.breach_name}</span>
                  <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-[#E54D2E]/10 text-[#E54D2E] border border-[#E54D2E]/20">
                    {b.source}
                  </span>
                </div>
                <p className="text-xs text-[#A1A3AA] mt-1 font-mono">ACCOUNT: {b.account_name}</p>
                {b.breach_date && <p className="text-[11px] text-[#6B6E78] font-mono">LEAK TIMESTAMP: {b.breach_date.split("T")[0]}</p>}
                {b.data_exposed.length > 0 && (
                  <div className="flex flex-wrap gap-1.5 mt-2">
                    {b.data_exposed.map((d) => (
                      <span key={d} className="text-[10px] font-mono px-2 py-0.5 rounded bg-[#0B0C0E] border border-[#222429] text-[#A1A3AA]">
                        {d}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ))}
          {history.length === 0 && (
            <div className="text-center py-12 text-xs font-mono text-[#6B6E78]">
              No confirmed breach occurrences logged. Trigger recon scan above.
            </div>
          )}
        </div>
      )}

      {/* Tab 3: Predictions */}
      {activeTab === "predict" && (
        <div className="space-y-3">
          <p className="text-xs text-[#A1A3AA]">
            Algorithmic forecast of credential vulnerability and breach probability over the upcoming 180-day window.
          </p>
          {predictions.map((p, i) => (
            <div key={i} className="monolith-card p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-bold font-display text-[#F4F4F6]">{p.service}</span>
                <span
                  className="text-xs font-mono font-bold px-2 py-0.5 rounded border"
                  style={{
                    backgroundColor: `${riskColors[p.risk_level] || "#D4D6DC"}15`,
                    borderColor: `${riskColors[p.risk_level] || "#D4D6DC"}30`,
                    color: riskColors[p.risk_level] || "#D4D6DC",
                  }}
                >
                  {p.probability_6_months}% PROBABILITY
                </span>
              </div>
              <div className="w-full bg-[#0B0C0E] rounded-full h-1.5 mb-2 overflow-hidden">
                <div
                  className="h-full rounded-full transition-all duration-700"
                  style={{
                    width: `${p.probability_6_months}%`,
                    backgroundColor: riskColors[p.risk_level] || "#D4D6DC",
                  }}
                />
              </div>
              <p className="text-xs text-[#A1A3AA]">{p.recommendation}</p>
              <div className="flex flex-wrap gap-3 mt-2 text-[10px] font-mono text-[#6B6E78]">
                {Object.entries(p.factors).map(([k, v]) => (
                  <span key={k}>
                    {k.replace(/_/g, " ").toUpperCase()}: {v}%
                  </span>
                ))}
              </div>
            </div>
          ))}
          {predictions.length === 0 && (
            <div className="text-center py-12 text-xs font-mono text-[#6B6E78]">
              Generating predictive vulnerability heuristics...
            </div>
          )}
        </div>
      )}
    </div>
  );
}
