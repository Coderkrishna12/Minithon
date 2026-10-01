import type { Metadata } from "next";
import { Inter, Space_Grotesk } from "next/font/google";
import "./globals.css";
import LayoutWrapper from "@/components/LayoutWrapper";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });
const spaceGrotesk = Space_Grotesk({ subsets: ["latin"], variable: "--font-space-grotesk" });

export const metadata: Metadata = {
  title: "PrivacyShield - Nordic Monolith Security Enclave",
  description: "Digital Footprint & Hardware-Backed Privacy Risk Auditor",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${spaceGrotesk.variable} h-full dark`}>
      <body className="min-h-full bg-[#0B0C0E] text-[#F4F4F6] font-sans antialiased selection:bg-[#F4F4F6] selection:text-[#0B0C0E]">
        <LayoutWrapper>{children}</LayoutWrapper>
      </body>
    </html>
  );
}
