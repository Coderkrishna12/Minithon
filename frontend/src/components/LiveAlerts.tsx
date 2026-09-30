"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { API_BASE } from "@/lib/api";

interface BreachAlert {
  id: number;
  service: string | null;
  breach: string;
  email?: string;
  confirmed?: boolean;
  unlisted?: boolean;
}

export default function LiveAlerts() {
  const pathname = usePathname();
  const [alerts, setAlerts] = useState<BreachAlert[]>([]);
  const [live, setLive] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (!token || pathname === "/" || pathname === "/login" || pathname === "/register") return;

    const ws = new WebSocket(`${API_BASE.replace(/^http/, "ws")}/ws/breach-monitor?token=${encodeURIComponent(token)}`);
    ws.onopen = () => setLive(true);
    ws.onclose = () => setLive(false);
    ws.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.type !== "breach_alert") return;
      setAlerts((prev) => [{ id: Date.now() + Math.random(), ...msg.data }, ...prev].slice(0, 4));
    };
    return () => ws.close();
  }, [pathname]);

  const dismiss = (id: number) => setAlerts((prev) => prev.filter((a) => a.id !== id));

  if (!live && alerts.length === 0) return null;

  return (
    <div className="fixed right-6 bottom-6 z-[60] w-80 space-y-3">
      {alerts.map((a) => (
        <div key={a.id} className="bg-card border border-ink rounded-sm shadow-[0_12px_30px_-18px_rgba(23,21,15,0.6)] p-4 animate-slide-up">
          <div className="flex items-start justify-between gap-3">
            <p className="eyebrow text-signal">{a.unlisted ? "Unlisted exposure" : a.confirmed ? "Your account leaked" : "Service breached"}</p>
            <button onClick={() => dismiss(a.id)} className="text-ink-3 hover:text-ink text-sm leading-none" aria-label="Dismiss">
              &times;
            </button>
          </div>
          <p className="font-serif text-xl mt-2 leading-tight">{a.breach}</p>
          <p className="text-sm text-ink-2 mt-1">
            {a.unlisted ? `${a.email} was found in this breach.` : `Affects your ${a.service} account.`}
          </p>
        </div>
      ))}
      {live && (
        <p className="eyebrow flex items-center justify-end gap-2">
          <span className="w-1.5 h-1.5 bg-ok rounded-full animate-pulse" /> Live monitoring
        </p>
      )}
    </div>
  );
}
