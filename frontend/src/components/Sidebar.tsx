"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import api from "@/lib/api";

const navSections = [
  {
    title: "PRIMARY ENCLAVES",
    items: [
      {
        href: "/dashboard",
        label: "Dashboard",
        code: "01",
        icon: "M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-4 0h4",
      },
      {
        href: "/accounts",
        label: "Accounts Vault",
        code: "02",
        icon: "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z",
      },
      {
        href: "/graph",
        label: "Identity Graph",
        code: "03",
        icon: "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1",
      },
      {
        href: "/breaches",
        label: "Breach Intel",
        code: "04",
        icon: "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z",
      },
      {
        href: "/ai-chat",
        label: "PrivacyBot AI",
        code: "05",
        icon: "M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z",
      },
    ],
  },
  {
    title: "INTELLIGENCE & AUDITING",
    items: [
      {
        href: "/blockchain",
        label: "Ledger Audit",
        code: "06",
        icon: "M21 7.5l-9-5.25L3 7.5m18 0l-9 5.25m9-5.25v9l-9 5.25M3 7.5l9 5.25M3 7.5v9l9 5.25m0-9v9",
      },
      {
        href: "/badges",
        label: "NFT Leveling",
        code: "07",
        icon: "M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-4.5A3.375 3.375 0 0012.75 10.5h-1.5A3.375 3.375 0 007.875 13.875v4.875m9 0H7.875",
      },
      {
        href: "/timeline",
        label: "Incident Timeline",
        code: "08",
        icon: "M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z",
      },
      {
        href: "/family",
        label: "Family Perimeter",
        code: "09",
        icon: "M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z",
      },
      {
        href: "/reports",
        label: "Executive Briefs",
        code: "10",
        icon: "M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z",
      },
      {
        href: "/search",
        label: "Search Index",
        code: "11",
        icon: "M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z",
      },
    ],
  },
];

export default function Sidebar() {
  const pathname = usePathname();
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    if (typeof window !== "undefined" && localStorage.getItem("token")) {
      api
        .get("/notifications/count")
        .then((r) => setUnread(r.data.unread_count ?? r.data.unread ?? 0))
        .catch(() => {});
    }
  }, [pathname]);

  if (pathname === "/login" || pathname === "/register" || pathname === "/") {
    return null;
  }

  return (
    <aside className="fixed left-0 top-0 h-full w-64 bg-[#0E0F12] border-r border-[#222429] flex flex-col z-50 select-none">
      {/* Brand Header */}
      <div className="p-5 border-b border-[#222429]">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 bg-[#17191E] border border-[#2B2E36] rounded-md flex items-center justify-center">
              <span className="w-2.5 h-2.5 bg-[#F4F4F6] rotate-45 rounded-[1px]" />
            </div>
            <div>
              <h1 className="text-sm font-bold tracking-widest text-[#F4F4F6] font-display">
                PRIVACYSHIELD
              </h1>
              <p className="text-[10px] text-[#6B6E78] tracking-wider uppercase font-display">
                Nordic Enclave // v2.0
              </p>
            </div>
          </div>
          <span className="text-[9px] font-mono text-[#3E9B66] bg-[#3E9B66]/10 px-1.5 py-0.5 rounded border border-[#3E9B66]/20">
            ONLINE
          </span>
        </div>
      </div>

      {/* Navigation Sections */}
      <nav className="flex-1 px-3 py-4 space-y-5 overflow-y-auto">
        {navSections.map((section) => (
          <div key={section.title} className="space-y-1">
            <h2 className="px-3 text-[10px] font-bold tracking-widest text-[#6B6E78] uppercase font-display">
              {section.title}
            </h2>
            <div className="space-y-0.5 pt-1">
              {section.items.map((item) => {
                const active = pathname.startsWith(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`flex items-center justify-between px-3 py-2 rounded-md text-xs font-medium transition-all group ${
                      active
                        ? "bg-[#18191E] text-[#F4F4F6] border border-[#2B2E36]"
                        : "text-[#A1A3AA] hover:text-[#F4F4F6] hover:bg-[#141519] border border-transparent"
                    }`}
                  >
                    <div className="flex items-center gap-2.5">
                      <svg
                        className={`w-4 h-4 flex-shrink-0 transition-colors ${
                          active ? "text-[#F4F4F6]" : "text-[#6B6E78] group-hover:text-[#A1A3AA]"
                        }`}
                        fill="none"
                        viewBox="0 0 24 24"
                        strokeWidth={1.5}
                        stroke="currentColor"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" d={item.icon} />
                      </svg>
                      <span className="font-display tracking-wide">{item.label}</span>
                    </div>
                    <span className="text-[10px] font-mono text-[#4A4D57] group-hover:text-[#6B6E78]">
                      {item.code}
                    </span>
                  </Link>
                );
              })}
            </div>
          </div>
        ))}

        {/* Notifications Tab */}
        <div className="pt-2 border-t border-[#222429]">
          <Link
            href="/notifications"
            className={`flex items-center justify-between px-3 py-2 rounded-md text-xs font-medium transition-all group ${
              pathname === "/notifications"
                ? "bg-[#18191E] text-[#F4F4F6] border border-[#2B2E36]"
                : "text-[#A1A3AA] hover:text-[#F4F4F6] hover:bg-[#141519] border border-transparent"
            }`}
          >
            <div className="flex items-center gap-2.5">
              <svg
                className={`w-4 h-4 flex-shrink-0 ${
                  pathname === "/notifications" ? "text-[#F4F4F6]" : "text-[#6B6E78]"
                }`}
                fill="none"
                viewBox="0 0 24 24"
                strokeWidth={1.5}
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"
                />
              </svg>
              <span className="font-display tracking-wide">Incident Feed</span>
            </div>
            {unread > 0 && (
              <span className="bg-[#E54D2E] text-white text-[10px] font-mono px-1.5 py-0.2 rounded-full font-bold">
                {unread}
              </span>
            )}
          </Link>
        </div>
      </nav>

      {/* Footer / Account Exit */}
      <div className="p-3 border-t border-[#222429]">
        <button
          onClick={() => {
            localStorage.removeItem("token");
            window.location.href = "/login";
          }}
          className="flex items-center gap-2.5 px-3 py-2 rounded-md text-xs text-[#A1A3AA] hover:text-[#E54D2E] hover:bg-[#E54D2E]/10 transition-all w-full font-display"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"
            />
          </svg>
          TERMINATE SESSION
        </button>
      </div>
    </aside>
  );
}
