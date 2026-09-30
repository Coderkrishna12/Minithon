"use client";

import Link from "next/link";
import PasswordLeakCheck from "@/components/PasswordLeakCheck";
import Wordmark from "@/components/Wordmark";

const stats = [
  { value: "900M+", label: "Breached passwords indexed" },
  { value: "5", label: "Hash characters we send" },
  { value: "0", label: "Accounts needed" },
];

const steps = [
  {
    no: "01",
    title: "Map every account",
    body: "Add the services you use. We chart how they connect through single sign-on, recovery emails and shared passwords.",
  },
  {
    no: "02",
    title: "Trace the cascade",
    body: "Pick any account and watch what falls if it is taken over. One weak inbox can hand over twenty other logins.",
  },
  {
    no: "03",
    title: "Fix in the right order",
    body: "Each fix is ranked by how much total risk it removes, then written to a hash-chained audit log.",
  },
];

export default function Home() {
  return (
    <div className="fixed inset-0 z-10 overflow-y-auto bg-paper">
      <header className="max-w-6xl mx-auto px-5 md:px-10 py-6 flex items-center justify-between">
        <Wordmark />
        <nav className="flex items-center gap-5 text-sm">
          <Link href="/login" className="text-ink-2 hover:text-ink transition-colors">
            Sign in
          </Link>
          <Link href="/register" className="bg-ink text-card px-4 py-2 rounded-sm hover:bg-signal transition-colors">
            Open your file
          </Link>
        </nav>
      </header>

      <section className="max-w-6xl mx-auto px-5 md:px-10 pt-8 md:pt-14 pb-20 grid lg:grid-cols-[1.1fr_1fr] lg:grid-rows-[auto_1fr] gap-x-16 gap-y-12">
        <div className="animate-slide-up lg:col-start-1 lg:row-start-1">
          <p className="eyebrow">Case file &middot; Personal exposure audit</p>
          <h1 className="mt-5 text-[3.1rem] md:text-[4.9rem] leading-[0.95]">
            Find out what a stranger <em className="text-signal">already</em> knows about you.
          </h1>
          <p className="mt-6 text-lg text-ink-2 max-w-md leading-relaxed">
            PrivacyShield maps the accounts you own, shows which single breach would unlock the rest, and tells you
            what to fix first.
          </p>
        </div>

        <div className="animate-slide-up [animation-delay:120ms] lg:col-start-2 lg:row-start-1 lg:row-span-2">
          <PasswordLeakCheck />
        </div>

        <div className="grid grid-cols-3 border-t border-ink self-start lg:col-start-1 lg:row-start-2">
          {stats.map((s, i) => (
            <div key={s.label} className={`pt-4 pr-3 ${i > 0 ? "pl-4 border-l border-rule" : ""}`}>
              <p className="num text-4xl md:text-5xl leading-none">{s.value}</p>
              <p className="eyebrow mt-3 leading-snug">{s.label}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="border-t border-rule bg-card">
        <div className="max-w-6xl mx-auto px-5 md:px-10 py-16">
          <p className="eyebrow">How the audit works</p>
          <div className="mt-8 grid md:grid-cols-3 gap-10 md:gap-12">
            {steps.map((step) => (
              <div key={step.no} className="border-t border-ink pt-5">
                <p className="font-mono text-sm text-signal">{step.no}</p>
                <h2 className="mt-3 text-3xl">{step.title}</h2>
                <p className="mt-3 text-ink-2 leading-relaxed">{step.body}</p>
              </div>
            ))}
          </div>
          <div className="mt-14 flex flex-wrap items-center gap-4">
            <Link href="/register" className="bg-ink text-card px-6 py-3 rounded-sm hover:bg-signal transition-colors">
              Start your audit
            </Link>
            <span className="text-sm text-ink-3">Takes about two minutes. Free.</span>
          </div>
        </div>
      </section>

      <footer className="border-t border-rule">
        <div className="max-w-6xl mx-auto px-5 md:px-10 py-6 flex flex-col md:flex-row justify-between gap-2 eyebrow">
          <span>Passwords are checked with k-anonymity. Nothing you type here is stored.</span>
          <span>Breach data: Have I Been Pwned</span>
        </div>
      </footer>
    </div>
  );
}
