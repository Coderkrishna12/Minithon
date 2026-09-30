"use client";

import { useState, useRef, useEffect } from "react";
import api from "@/lib/api";

interface Message {
  role: "user" | "assistant";
  content: string;
}

export default function AIChatPage() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || loading) return;

    const userMsg: Message = { role: "user", content: input.trim() };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setLoading(true);

    try {
      const res = await api.post("/ai/chat", {
        message: userMsg.content,
        history: messages,
      });
      setMessages((prev) => [...prev, { role: "assistant", content: res.data.response }]);
    } catch {
      setMessages((prev) => [...prev, { role: "assistant", content: "Sorry, I encountered an error. Please try again." }]);
    } finally {
      setLoading(false);
    }
  };

  const quickQuestions = [
    "What's my biggest risk?",
    "What if my email gets hacked?",
    "How do I set up 2FA?",
    "Which passwords should I change first?",
    "Review my app permissions",
  ];

  return (
    <div className="flex flex-col h-[calc(100vh-4rem)]">
      <div className="mb-4">
        <h1 className="text-2xl font-bold">PrivacyBot</h1>
        <p className="text-[#94A3B8] text-sm mt-1">AI-powered security assistant — ask anything about your digital privacy</p>
      </div>

      <div className="flex-1 overflow-y-auto space-y-4 pb-4">
        {messages.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full text-center">
            <div className="w-16 h-16 bg-[#8B5CF6]/20 rounded-2xl flex items-center justify-center mb-4">
              <svg className="w-8 h-8 text-[#8B5CF6]" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
              </svg>
            </div>
            <h2 className="text-lg font-semibold mb-2">Ask PrivacyBot</h2>
            <p className="text-[#64748B] text-sm mb-6 max-w-md">
              I analyze your account network and give personalized security advice. Try one of these:
            </p>
            <div className="flex flex-wrap gap-2 justify-center max-w-lg">
              {quickQuestions.map((q) => (
                <button
                  key={q}
                  onClick={() => { setInput(q); }}
                  className="px-4 py-2 bg-[#1E293B] border border-[#334155] rounded-xl text-sm text-[#94A3B8] hover:text-white hover:border-[#8B5CF6] transition-all"
                >
                  {q}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((msg, i) => (
          <div key={i} className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}>
            <div
              className={`max-w-[70%] rounded-2xl px-5 py-3 ${
                msg.role === "user"
                  ? "bg-[#3B82F6] text-white"
                  : "bg-[#1E293B] border border-[#334155] text-[#F8FAFC]"
              }`}
            >
              <div className="text-sm whitespace-pre-wrap leading-relaxed"
                dangerouslySetInnerHTML={{
                  __html: msg.content
                    .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
                    .replace(/\n/g, "<br/>")
                }}
              />
            </div>
          </div>
        ))}

        {loading && (
          <div className="flex justify-start">
            <div className="bg-[#1E293B] border border-[#334155] rounded-2xl px-5 py-3">
              <div className="flex gap-1.5">
                <div className="w-2 h-2 rounded-full bg-[#8B5CF6] animate-bounce" style={{ animationDelay: "0ms" }} />
                <div className="w-2 h-2 rounded-full bg-[#8B5CF6] animate-bounce" style={{ animationDelay: "150ms" }} />
                <div className="w-2 h-2 rounded-full bg-[#8B5CF6] animate-bounce" style={{ animationDelay: "300ms" }} />
              </div>
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      <form onSubmit={sendMessage} className="flex gap-3 pt-4 border-t border-[#334155]">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask about your digital security..."
          className="flex-1 px-5 py-3 bg-[#1E293B] border border-[#334155] rounded-xl text-white placeholder-[#64748B] focus:outline-none focus:border-[#8B5CF6] transition-colors"
          disabled={loading}
        />
        <button
          type="submit"
          disabled={loading || !input.trim()}
          className="px-6 py-3 bg-[#8B5CF6] hover:bg-[#7C3AED] disabled:opacity-50 text-white rounded-xl font-medium transition-all"
        >
          Send
        </button>
      </form>
    </div>
  );
}
