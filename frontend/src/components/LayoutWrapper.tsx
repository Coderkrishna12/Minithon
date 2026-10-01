"use client";

import { usePathname } from "next/navigation";
import Sidebar from "@/components/Sidebar";

export default function LayoutWrapper({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isAuthPage = pathname === "/login" || pathname === "/register" || pathname === "/";

  if (isAuthPage) {
    return (
      <main className="min-h-screen w-full bg-[#0B0C0E] text-[#F4F4F6] overflow-x-hidden">
        {children}
      </main>
    );
  }

  return (
    <div className="min-h-screen w-full flex bg-[#0B0C0E] text-[#F4F4F6]">
      <Sidebar />
      <main className="flex-1 ml-64 p-8 overflow-y-auto bg-[#0B0C0E] text-[#F4F4F6]">
        <div className="max-w-7xl mx-auto">
          {children}
        </div>
      </main>
    </div>
  );
}
