"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";

interface ScorePoint {
  date: string;
  score: number;
}

interface TimelineEvent {
  id: number;
  title: string;
  description: string;
  severity: string;
  timestamp: string;
  category: string;
}

const severityColors: Record<string, string> = {
  critical: "#C8321A",
  warning: "#A8660F",
  info: "#23408E",
};

export default function TimelinePage() {
  const [scoreHistory, setScoreHistory] = useState<ScorePoint[]>([]);
  const [events, setEvents] = useState<TimelineEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [snapshotting, setSnapshotting] = useState(false);

  useEffect(() => {
    Promise.all([
      api.get("/timeline/score-history").catch(() => ({ data: [] })),
      api.get("/timeline/events").catch(() => ({ data: [] })),
    ]).then(([historyRes, eventsRes]) => {
      setScoreHistory(Array.isArray(historyRes.data) ? historyRes.data : historyRes.data.history || []);
      setEvents(Array.isArray(eventsRes.data) ? eventsRes.data : eventsRes.data.events || []);
    }).finally(() => setLoading(false));
  }, []);

  const takeSnapshot = async () => {
    setSnapshotting(true);
    try {
      const res = await api.post("/timeline/snapshot");
      const newPoint: ScorePoint = { date: new Date().toISOString().split("T")[0], score: res.data.score ?? res.data.privacy_score ?? 0 };
      setScoreHistory((prev) => [...prev, newPoint]);
    } catch {}
    setSnapshotting(false);
  };

  const maxScore = Math.max(...scoreHistory.map((p) => p.score), 100);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="w-10 h-10 border-2 border-[#17150F] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="eyebrow mb-3">Record &middot; 09</p>
          <h1 className="page-title">Timeline</h1>
          <p className="text-[#5B544A] text-sm mt-1">Privacy score history and security events</p>
        </div>
        <button
          onClick={takeSnapshot}
          disabled={snapshotting}
          className="px-5 py-2.5 bg-[#17150F] hover:bg-[#C8321A] disabled:opacity-50 text-white rounded-sm text-sm font-medium transition-all"
        >
          {snapshotting ? "Taking Snapshot..." : "Take Score Snapshot"}
        </button>
      </div>

      {/* Score History Chart */}
      <div className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-6">
        <h2 className="section-title mb-4">Privacy Score History</h2>
        {scoreHistory.length > 0 ? (
          <div className="space-y-3">
            <div className="flex items-end gap-1 h-48">
              {scoreHistory.map((point, i) => {
                const height = (point.score / maxScore) * 100;
                const color = point.score >= 80 ? "#2E6B4E" : point.score >= 60 ? "#23408E" : point.score >= 40 ? "#A8660F" : "#C8321A";
                return (
                  <div key={i} className="flex-1 flex flex-col items-center justify-end h-full group relative">
                    <div className="absolute -top-6 left-1/2 -translate-x-1/2 opacity-0 group-hover:opacity-100 transition-opacity bg-[#F2EEE5] text-xs px-2 py-1 rounded whitespace-nowrap z-10">
                      {point.score.toFixed(0)}
                    </div>
                    <div
                      className="w-full max-w-[40px] rounded-t-lg transition-all group-hover:opacity-80"
                      style={{ height: `${height}%`, backgroundColor: color, minHeight: "4px" }}
                    />
                  </div>
                );
              })}
            </div>
            <div className="flex gap-1">
              {scoreHistory.map((point, i) => (
                <div key={i} className="flex-1 text-center">
                  <span className="text-[10px] text-[#8A8274]">
                    {new Date(point.date).toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                  </span>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div className="text-center py-12 text-[#8A8274]">
            <p>No score history yet. Take a snapshot to start tracking.</p>
          </div>
        )}
      </div>

      {/* Events Timeline */}
      <div className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-6">
        <h2 className="section-title mb-4">Security Events</h2>
        {events.length > 0 ? (
          <div className="space-y-0">
            {events.map((event, i) => {
              const color = severityColors[event.severity] || "#23408E";
              const showDateLabel = i === 0 || new Date(event.timestamp).toDateString() !== new Date(events[i - 1].timestamp).toDateString();
              return (
                <div key={event.id}>
                  {showDateLabel && (
                    <div className="flex items-center gap-3 py-2">
                      <span className="text-xs font-medium text-[#5B544A]">
                        {new Date(event.timestamp).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric", year: "numeric" })}
                      </span>
                      <div className="flex-1 h-px bg-[#DCD4C4]" />
                    </div>
                  )}
                  <div className="flex gap-4 py-3">
                    <div className="flex flex-col items-center">
                      <div className="w-3 h-3 rounded-full flex-shrink-0 mt-1" style={{ backgroundColor: color }} />
                      {i < events.length - 1 && <div className="w-px flex-1 bg-[#DCD4C4] mt-1" />}
                    </div>
                    <div className="flex-1 pb-2">
                      <div className="flex items-center gap-2 mb-1">
                        <span className="font-medium text-sm">{event.title}</span>
                        <span
                          className="text-[10px] px-2 py-0.5 rounded-full font-medium capitalize"
                          style={{ backgroundColor: `${color}20`, color }}
                        >
                          {event.severity}
                        </span>
                      </div>
                      <p className="text-xs text-[#8A8274]">{event.description}</p>
                      <p className="text-[10px] text-[#8A8274] mt-1">
                        {new Date(event.timestamp).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" })}
                        {event.category && <span> &middot; {event.category}</span>}
                      </p>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="text-center py-12 text-[#8A8274]">
            <p>No security events recorded yet.</p>
          </div>
        )}
      </div>
    </div>
  );
}
