"use client";

import { Fragment, useEffect, useRef, useState } from "react";
import api from "@/lib/api";

interface Source {
  n: number;
  title: string;
  type: string;
  label: string;
  url: string | null;
  snippet: string;
  cited: boolean;
}

interface Message {
  role: "user" | "assistant";
  content: string;
  error?: string | null;
  sources?: Source[];
  retrieval?: { mode: string; searched: number };
}

interface IndexStatus {
  retrieval: string;
  generation: string | null;
  chunks: Record<string, { total: number; embedded: number }>;
}

const quickQuestions = [
  "What's my biggest risk?",
  "Which passwords should I change first?",
  "What leaked in the breaches on my accounts?",
  "If my email is hacked, what else falls?",
];

function Inline({ text, msgIndex }: { text: string; msgIndex: number }) {
  const parts = text.split(/(\*\*[^*]+\*\*|\[\d+\])/g);
  return (
    <>
      {parts.map((part, i) => {
        const bold = part.match(/^\*\*([^*]+)\*\*$/);
        if (bold) return <strong key={i}>{bold[1]}</strong>;
        const cite = part.match(/^\[(\d+)\]$/);
        if (cite) {
          return (
            <a
              key={i}
              href={`#src-${msgIndex}-${cite[1]}`}
              className="inline-block align-[2px] mx-0.5 px-1 font-mono text-[0.65rem] leading-4 border border-ink text-ink hover:bg-ink hover:text-card"
            >
              {cite[1]}
            </a>
          );
        }
        return <Fragment key={i}>{part}</Fragment>;
      })}
    </>
  );
}

function SourceList({ sources, msgIndex, answered }: { sources: Source[]; msgIndex: number; answered: boolean }) {
  const ordered = [...sources].sort((a, b) => Number(b.cited) - Number(a.cited) || a.n - b.n);
  return (
    <div className="mt-4 pt-3 border-t border-dashed border-rule-strong">
      <p className="eyebrow mb-2">Retrieved records</p>
      <ol className="space-y-2">
        {ordered.map((s) => (
          <li key={s.n} id={`src-${msgIndex}-${s.n}`} className={`flex gap-3 text-sm ${answered && !s.cited ? "opacity-60" : ""}`}>
            <span className="font-mono text-[0.7rem] w-5 shrink-0 pt-0.5 text-ink-3">{s.n}</span>
            <div className="min-w-0">
              <p className="eyebrow">{s.label}{s.cited ? " · cited" : ""}</p>
              <p className="font-medium">
                {s.url ? (
                  <a href={s.url} target="_blank" rel="noreferrer" className="hover:underline underline-offset-4">
                    {s.title}
                  </a>
                ) : (
                  s.title
                )}
              </p>
              <p className="text-ink-2 text-[0.8rem] leading-snug line-clamp-2">{s.snippet}</p>
            </div>
          </li>
        ))}
      </ol>
    </div>
  );
}

export default function AIChatPage() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<IndexStatus | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    api.get("/ai/rag/status").then((r) => setStatus(r.data)).catch(() => {});
  }, []);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const ask = async (question: string) => {
    if (!question.trim() || loading) return;
    const history = messages.filter((m) => m.content).map(({ role, content }) => ({ role, content }));
    setMessages((prev) => [...prev, { role: "user", content: question.trim() }]);
    setInput("");
    setLoading(true);
    try {
      const { data } = await api.post("/ai/chat", { message: question.trim(), history });
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: data.response ?? "", error: data.error, sources: data.sources, retrieval: data.retrieval },
      ]);
      api.get("/ai/rag/status").then((r) => setStatus(r.data)).catch(() => {});
    } catch {
      setMessages((prev) => [...prev, { role: "assistant", content: "", error: "Couldn't reach PrivacyBot. Please try again." }]);
    } finally {
      setLoading(false);
    }
  };

  const totalChunks = status ? Object.values(status.chunks).reduce((sum, c) => sum + c.total, 0) : 0;

  return (
    <div className="flex flex-col h-[calc(100vh-6rem)]">
      <div className="mb-4 flex items-end justify-between gap-6">
        <div>
          <p className="eyebrow mb-3">Assist &middot; 06</p>
          <h1 className="page-title">PrivacyBot</h1>
          <p className="text-ink-2 text-sm mt-2">Answers drawn from your own records and the Have I Been Pwned breach catalog, with sources.</p>
        </div>
        {status && (
          <p className="eyebrow text-right leading-relaxed shrink-0">
            {totalChunks.toLocaleString()} indexed passages
            <br />
            {status.retrieval} retrieval &middot; {status.generation ? "Claude" : "no generator"}
          </p>
        )}
      </div>

      <div className="flex-1 overflow-y-auto space-y-5 pb-4 pr-1">
        {messages.length === 0 && (
          <div className="h-full flex flex-col justify-center max-w-xl">
            <h2 className="text-4xl leading-tight">Ask about your exposure.</h2>
            <p className="text-ink-2 mt-3">
              Each question searches your accounts, breaches, exposures, fixes and analysed privacy policies, then answers only
              from what it finds.
            </p>
            <div className="mt-6 border-t border-ink">
              {quickQuestions.map((q) => (
                <button
                  key={q}
                  onClick={() => ask(q)}
                  className="w-full text-left py-3 border-b border-rule text-ink-2 hover:text-ink flex justify-between group"
                >
                  {q}
                  <span className="text-ink-3 group-hover:text-signal">&rarr;</span>
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((msg, i) =>
          msg.role === "user" ? (
            <div key={i} className="flex justify-end">
              <div className="max-w-[70%] bg-ink text-card px-5 py-3 rounded-sm text-sm">{msg.content}</div>
            </div>
          ) : (
            <div key={i} className="max-w-[80%] bg-card border border-rule rounded-sm px-5 py-4">
              {msg.content && (
                <div className="text-[0.95rem] leading-relaxed whitespace-pre-wrap">
                  <Inline text={msg.content} msgIndex={i} />
                </div>
              )}
              {msg.error && <p className="text-sm text-signal">{msg.error}</p>}
              {msg.retrieval && (
                <p className="eyebrow mt-3">
                  {msg.retrieval.mode} search over {msg.retrieval.searched.toLocaleString()} passages
                </p>
              )}
              {msg.sources && msg.sources.length > 0 && <SourceList sources={msg.sources} msgIndex={i} answered={Boolean(msg.content)} />}
            </div>
          ),
        )}

        {loading && <p className="eyebrow animate-pulse">Searching your records&hellip;</p>}
        <div ref={bottomRef} />
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          ask(input);
        }}
        className="flex gap-3 pt-4 border-t border-rule"
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask about your accounts, breaches or fixes"
          className="flex-1 px-5 py-3 bg-card border border-rule rounded-sm text-ink placeholder:text-ink-3 focus:outline-none focus:border-ink transition-colors"
          disabled={loading}
        />
        <button
          type="submit"
          disabled={loading || !input.trim()}
          className="px-6 py-3 bg-ink hover:bg-signal disabled:opacity-40 text-card rounded-sm font-medium transition-colors"
        >
          Ask
        </button>
      </form>
    </div>
  );
}
