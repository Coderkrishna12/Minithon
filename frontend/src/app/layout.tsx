import type { Metadata } from "next";
import { IBM_Plex_Mono, IBM_Plex_Sans, Instrument_Serif } from "next/font/google";
import "./globals.css";
import Sidebar from "@/components/Sidebar";
import LiveAlerts from "@/components/LiveAlerts";

const plexSans = IBM_Plex_Sans({ subsets: ["latin"], weight: ["400", "500", "600"], variable: "--font-plex-sans" });
const plexMono = IBM_Plex_Mono({ subsets: ["latin"], weight: ["400", "500", "700"], variable: "--font-plex-mono" });
const instrument = Instrument_Serif({ subsets: ["latin"], weight: "400", style: ["normal", "italic"], variable: "--font-instrument" });

export const metadata: Metadata = {
  title: "PrivacyShield",
  description: "Find out what a stranger already knows about you.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${plexSans.variable} ${plexMono.variable} ${instrument.variable} h-full`}>
      <body className="min-h-full flex bg-paper text-ink">
        <Sidebar />
        <main className="flex-1 ml-64 overflow-auto">
          <div className="max-w-6xl mx-auto px-10 py-12">{children}</div>
        </main>
        <LiveAlerts />
      </body>
    </html>
  );
}
