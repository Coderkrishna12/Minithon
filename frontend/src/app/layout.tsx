import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Sidebar from "@/components/Sidebar";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });

export const metadata: Metadata = {
  title: "PrivacyShield",
  description: "Digital Footprint & Privacy Risk Auditor",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} h-full`}>
      <body className="min-h-full flex bg-[#0F172A] text-[#F8FAFC]">
        <Sidebar />
        <main className="flex-1 ml-64 p-8 overflow-auto">{children}</main>
      </body>
    </html>
  );
}
