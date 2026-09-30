"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import api from "@/lib/api";
import Wordmark from "@/components/Wordmark";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await api.post("/auth/login", { email, password });
      localStorage.setItem("token", res.data.access_token);
      router.push("/dashboard");
    } catch {
      setError("Invalid email or password");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-10 overflow-y-auto flex bg-[#F2EEE5] px-4 py-10">
      <div className="w-full max-w-md m-auto">
        <div className="mb-8">
          <Wordmark />
          <h1 className="page-title mt-10">Welcome back.</h1>
          <p className="text-[#5B544A] mt-3">Sign in to your account</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-[#FBF9F4] border border-[#DCD4C4] rounded-sm p-8 space-y-5">
          {error && (
            <div className="bg-[#C8321A]/10 border border-[#C8321A]/20 text-[#C8321A] px-4 py-3 rounded-sm text-sm">
              {error}
            </div>
          )}

          <div>
            <label className="block text-sm text-[#5B544A] mb-2">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] placeholder-[#8A8274] focus:outline-none focus:border-[#17150F] transition-colors"
              placeholder="you@example.com"
              required
            />
          </div>

          <div>
            <label className="block text-sm text-[#5B544A] mb-2">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-3 bg-[#F2EEE5] border border-[#DCD4C4] rounded-sm text-[#17150F] placeholder-[#8A8274] focus:outline-none focus:border-[#17150F] transition-colors"
              placeholder="Enter password"
              required
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-[#17150F] hover:bg-[#C8321A] disabled:opacity-50 text-white rounded-sm font-medium transition-all"
          >
            {loading ? "Signing in..." : "Sign In"}
          </button>

          <p className="text-center text-sm text-[#8A8274]">
            Don&apos;t have an account?{" "}
            <Link href="/register" className="text-[#23408E] hover:underline">Register</Link>
          </p>
        </form>
      </div>
    </div>
  );
}
