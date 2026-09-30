"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import api from "@/lib/api";
import Wordmark from "@/components/Wordmark";

const sections = [
  {
    title: "Audit",
    items: [
      { href: "/dashboard", label: "Overview" },
      { href: "/accounts", label: "Accounts" },
      { href: "/graph", label: "Risk graph" },
      { href: "/breaches", label: "Breach scanner" },
      { href: "/check", label: "Leak check" },
    ],
  },
  {
    title: "Assist",
    items: [
      { href: "/ai-chat", label: "PrivacyBot" },
      { href: "/search", label: "Search" },
      { href: "/family", label: "Family shield" },
    ],
  },
  {
    title: "Record",
    items: [
      { href: "/timeline", label: "Timeline" },
      { href: "/reports", label: "Reports" },
      { href: "/blockchain", label: "Audit log" },
      { href: "/badges", label: "Badges" },
    ],
  },
].reduce<{ title: string; items: { href: string; label: string; no: string }[] }[]>((acc, section) => {
  const start = acc.reduce((sum, s) => sum + s.items.length, 0);
  acc.push({
    title: section.title,
    items: section.items.map((item, i) => ({ ...item, no: String(start + i + 1).padStart(2, "0") })),
  });
  return acc;
}, []);

export default function Sidebar() {
  const pathname = usePathname();
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    if (typeof window !== "undefined" && localStorage.getItem("token")) {
      api.get("/notifications/count").then((r) => setUnread(r.data.unread)).catch(() => {});
    }
  }, [pathname]);

  if (pathname === "/login" || pathname === "/register" || pathname === "/") {
    return null;
  }

  return (
    <aside className="fixed left-0 top-0 h-full w-64 bg-card border-r border-rule flex flex-col z-50">
      <div className="px-7 pt-8 pb-6">
        <Wordmark size="text-[1.7rem]" href="/dashboard" />
        <p className="eyebrow mt-3">Exposure audit</p>
      </div>

      <nav className="flex-1 px-4 overflow-y-auto">
        {sections.map((section) => (
          <div key={section.title} className="mb-6">
            <p className="eyebrow px-3 pb-2 mb-1 border-b border-rule">{section.title}</p>
            {section.items.map((item) => {
              const active = pathname.startsWith(item.href);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`group relative flex items-baseline gap-3 px-3 py-[7px] text-[0.9rem] transition-colors ${
                    active ? "text-ink font-medium" : "text-ink-2 hover:text-ink"
                  }`}
                >
                  <span
                    className={`absolute left-0 top-1/2 -translate-y-1/2 h-4 w-[3px] bg-signal transition-opacity ${
                      active ? "opacity-100" : "opacity-0"
                    }`}
                  />
                  <span className="font-mono text-[0.68rem] text-ink-3 w-5">{item.no}</span>
                  <span className="group-hover:underline decoration-rule-strong underline-offset-4">{item.label}</span>
                </Link>
              );
            })}
          </div>
        ))}
      </nav>

      <div className="px-4 py-4 border-t border-rule space-y-1">
        <Link
          href="/notifications"
          className={`flex items-center justify-between px-3 py-2 text-[0.9rem] ${
            pathname === "/notifications" ? "text-ink font-medium" : "text-ink-2 hover:text-ink"
          }`}
        >
          Notifications
          {unread > 0 && (
            <span className="font-mono text-[0.7rem] bg-signal text-card px-1.5 py-0.5 rounded-[2px]">{unread}</span>
          )}
        </Link>
        <button
          onClick={() => {
            localStorage.removeItem("token");
            window.location.href = "/login";
          }}
          className="w-full text-left px-3 py-2 text-[0.9rem] text-ink-3 hover:text-signal transition-colors"
        >
          Sign out
        </button>
      </div>
    </aside>
  );
}
