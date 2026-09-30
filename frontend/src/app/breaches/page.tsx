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
  const [scanResult, setScanResult] = useState<{ total_accounts_scanned: number; affected_accounts: number; total_breaches_found: number } | null>(null);
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

  const riskColors: Record<string, string> = { critical: "#EF4444", high: "#F59E0B", medium: "#3B82F6", low: "#10B981" };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Breach Scanner</h1>
        <p className="text-[#94A3B8] text-sm mt-1">Check your accounts against known data breaches and predict future risks</p>
      </div>

      <div className="flex gap-2">
        {(["scan", "history", "predict"] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => {
              setActiveTab(tab);
              if (tab === "history" && history.length === 0) api.get("/breaches/history").then((r) => setHistory(r.data)).catch(() => {});
              if (tab === "predict" && predictions.length === 0) loadPredictions();
            }}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${
              activeTab === tab ? "bg-[#3B82F6] text-white" : "bg-[#1E293B] text-[#94A3B8] border border-[#334155]"
            }`}
          >
            {tab === "scan" ? "Scan Now" : tab === "history" ? "Breach History" : "AI Predictions"}
          </button>
        ))}
      </div>

      {activeTab === "scan" && (
        <div className="space-y-6">
          <div className="bg-[#1E293B] border border-[#334155] rounded-2xl p-8 text-center">
            <div className="w-16 h-16 bg-[#F59E0B]/20 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-[#F59E0B]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            </div>
            <h2 className="text-lg font-semibold mb-2">Breach Database Scan</h2>
            <p className="text-[#94A3B8] text-sm mb-6 max-w-md mx-auto">
              Scans all your accounts against HaveIBeenPwned and our known breach database. Checks email addresses and service names.
            </p>
            <button
              onClick={runScan}
              disabled={scanning}
              className="px-8 py-3 bg-[#F59E0B] hover:bg-[#D97706] disabled:opacity-50 text-black font-medium rounded-xl transition-all"
            >
              {scanning ? "Scanning..." : "Run Full Scan"}
            </button>
          </div>

          {scanResult && (
            <div className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6 animate-slide-up">
              <h3 className="text-lg font-semibold mb-4">Scan Results</h3>
              <div className="grid grid-cols-3 gap-4">
                <div className="bg-[#0F172A] rounded-xl p-4 text-center">
                  <p className="text-2xl font-bold text-[#3B82F6]">{scanResult.total_accounts_scanned}</p>
                  <p className="text-xs text-[#94A3B8]">Accounts Scanned</p>
                </div>
                <div className="bg-[#0F172A] rounded-xl p-4 text-center">
                  <p className="text-2xl font-bold text-[#EF4444]">{scanResult.affected_accounts}</p>
                  <p className="text-xs text-[#94A3B8]">Affected Accounts</p>
                </div>
                <div className="bg-[#0F172A] rounded-xl p-4 text-center">
                  <p className="text-2xl font-bold text-[#F59E0B]">{scanResult.total_breaches_found}</p>
                  <p className="text-xs text-[#94A3B8]">Breaches Found</p>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {activeTab === "history" && (
        <div className="space-y-3">
          {history.map((b) => (
            <div key={b.id} className="bg-[#1E293B] border border-[#334155] rounded-xl p-4 flex items-start gap-4">
              <div className="w-10 h-10 bg-[#EF4444]/20 rounded-xl flex items-center justify-center flex-shrink-0">
                <svg className="w-5 h-5 text-[#EF4444]" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="font-medium">{b.breach_name}</span>
                  <span className="text-xs px-2 py-0.5 rounded bg-[#EF4444]/15 text-[#EF4444]">{b.source}</span>
                </div>
                <p className="text-sm text-[#94A3B8] mt-1">Account: {b.account_name}</p>
                {b.breach_date && <p className="text-xs text-[#64748B]">Date: {b.breach_date.split("T")[0]}</p>}
                {b.data_exposed.length > 0 && (
                  <div className="flex flex-wrap gap-1 mt-2">
                    {b.data_exposed.map((d) => (
                      <span key={d} className="text-[10px] px-1.5 py-0.5 rounded bg-[#0F172A] text-[#94A3B8]">{d}</span>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ))}
          {history.length === 0 && <p className="text-center text-[#64748B] py-12">No breaches found. Run a scan first.</p>}
        </div>
      )}

      {activeTab === "predict" && (
        <div className="space-y-3">
          <p className="text-sm text-[#94A3B8] mb-4">AI-predicted breach probability for each account over the next 6 months</p>
          {predictions.map((p, i) => (
            <div key={i} className="bg-[#1E293B] border border-[#334155] rounded-xl p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="font-medium">{p.service}</span>
                <span
                  className="text-sm font-bold px-3 py-1 rounded-full"
                  style={{ backgroundColor: `${riskColors[p.risk_level] || "#3B82F6"}20`, color: riskColors[p.risk_level] || "#3B82F6" }}
                >
                  {p.probability_6_months}%
                </span>
              </div>
              <div className="w-full bg-[#0F172A] rounded-full h-2 mb-3">
                <div
                  className="h-2 rounded-full transition-all duration-500"
                  style={{ width: `${p.probability_6_months}%`, backgroundColor: riskColors[p.risk_level] || "#3B82F6" }}
                />
              </div>
              <p className="text-xs text-[#94A3B8]">{p.recommendation}</p>
              <div className="flex gap-3 mt-2">
                {Object.entries(p.factors).map(([k, v]) => (
                  <span key={k} className="text-[10px] text-[#64748B]">{k.replace(/_/g, " ")}: {v}%</span>
                ))}
              </div>
            </div>
          ))}
          {predictions.length === 0 && <p className="text-center text-[#64748B] py-12">Loading predictions...</p>}
        </div>
      )}
    </div>
  );
}
