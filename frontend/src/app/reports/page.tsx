"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";

interface ReportSummary {
  grade: string;
  score: number;
  strengths: string[];
  weaknesses: string[];
  recommendations: string[];
}

const gradeColors: Record<string, string> = {
  "A+": "#10B981",
  A: "#10B981",
  "A-": "#10B981",
  "B+": "#3B82F6",
  B: "#3B82F6",
  "B-": "#3B82F6",
  "C+": "#F59E0B",
  C: "#F59E0B",
  "C-": "#F59E0B",
  D: "#EF4444",
  F: "#EF4444",
};

export default function ReportsPage() {
  const [summary, setSummary] = useState<ReportSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [exportData, setExportData] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    api.get("/reports/summary")
      .then((r) => setSummary(r.data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const exportReport = async () => {
    setExporting(true);
    try {
      const res = await api.get("/reports/export");
      setExportData(JSON.stringify(res.data, null, 2));
    } catch {}
    setExporting(false);
  };

  const copyToClipboard = async () => {
    if (!exportData) return;
    try {
      await navigator.clipboard.writeText(exportData);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {}
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="w-10 h-10 border-2 border-[#3B82F6] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Reports</h1>
          <p className="text-[#94A3B8] text-sm mt-1">Privacy audit summary and exportable reports</p>
        </div>
        <button
          onClick={exportReport}
          disabled={exporting}
          className="px-5 py-2.5 bg-[#8B5CF6] hover:bg-[#7C3AED] disabled:opacity-50 text-white rounded-xl text-sm font-medium transition-all"
        >
          {exporting ? "Exporting..." : "Export Full Report"}
        </button>
      </div>

      {/* Summary Card */}
      {summary && (
        <div className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6">
          <div className="flex items-center gap-6 mb-6">
            <div
              className="w-24 h-24 rounded-2xl flex items-center justify-center text-3xl font-black"
              style={{
                backgroundColor: `${gradeColors[summary.grade] || "#94A3B8"}20`,
                color: gradeColors[summary.grade] || "#94A3B8",
              }}
            >
              {summary.grade}
            </div>
            <div>
              <p className="text-sm text-[#94A3B8]">Privacy Score</p>
              <p className="text-4xl font-bold" style={{ color: gradeColors[summary.grade] || "#94A3B8" }}>
                {summary.score}<span className="text-lg text-[#64748B]">/100</span>
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Strengths */}
            <div>
              <h3 className="text-sm font-semibold text-[#10B981] mb-3 flex items-center gap-2">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
                Strengths
              </h3>
              <div className="space-y-2">
                {summary.strengths.map((s, i) => (
                  <div key={i} className="flex items-start gap-2 text-sm text-[#94A3B8]">
                    <span className="text-[#10B981] mt-0.5">+</span>
                    <span>{s}</span>
                  </div>
                ))}
                {summary.strengths.length === 0 && (
                  <p className="text-sm text-[#64748B]">No strengths identified yet</p>
                )}
              </div>
            </div>

            {/* Weaknesses */}
            <div>
              <h3 className="text-sm font-semibold text-[#EF4444] mb-3 flex items-center gap-2">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
                </svg>
                Weaknesses
              </h3>
              <div className="space-y-2">
                {summary.weaknesses.map((w, i) => (
                  <div key={i} className="flex items-start gap-2 text-sm text-[#94A3B8]">
                    <span className="text-[#EF4444] mt-0.5">-</span>
                    <span>{w}</span>
                  </div>
                ))}
                {summary.weaknesses.length === 0 && (
                  <p className="text-sm text-[#64748B]">No weaknesses found</p>
                )}
              </div>
            </div>
          </div>

          {/* Recommendations */}
          {summary.recommendations && summary.recommendations.length > 0 && (
            <div className="mt-6 pt-6 border-t border-[#334155]">
              <h3 className="text-sm font-semibold text-[#F59E0B] mb-3 flex items-center gap-2">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18" />
                </svg>
                Recommendations
              </h3>
              <div className="space-y-2">
                {summary.recommendations.map((r, i) => (
                  <div key={i} className="flex items-start gap-2 text-sm text-[#94A3B8]">
                    <span className="text-[#F59E0B] mt-0.5">{i + 1}.</span>
                    <span>{r}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {!summary && (
        <div className="text-center py-16 bg-[#1E293B] border border-[#334155] rounded-2xl">
          <p className="text-[#64748B] text-lg">No report data available</p>
          <p className="text-[#64748B] text-sm mt-1">Add accounts and run a privacy audit to generate a report</p>
        </div>
      )}

      {/* Exported Report */}
      {exportData && (
        <div className="bg-[#1E293B] border border-[#334155] rounded-2xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold">Exported Report</h2>
            <button
              onClick={copyToClipboard}
              className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${
                copied
                  ? "bg-[#10B981]/20 text-[#10B981]"
                  : "bg-[#334155] hover:bg-[#475569] text-[#94A3B8]"
              }`}
            >
              {copied ? "Copied!" : "Copy to Clipboard"}
            </button>
          </div>
          <pre className="bg-[#0F172A] border border-[#334155] rounded-xl p-4 overflow-x-auto text-xs text-[#94A3B8] font-mono max-h-96 overflow-y-auto">
            {exportData}
          </pre>
        </div>
      )}
    </div>
  );
}
