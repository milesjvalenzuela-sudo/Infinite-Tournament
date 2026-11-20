 "use client";

import Link from "next/link";
import { useState } from "react";
import { getSupabase } from "@/lib/supabase";

export default function AccountPage() {
  const [mode, setMode] = useState<"signup" | "login">("signup");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true);
    setMessage("");
    try {
      const supabase = getSupabase();
      const result = mode === "signup"
        ? await supabase.auth.signUp({ email, password })
        : await supabase.auth.signInWithPassword({ email, password });
      if (result.error) throw result.error;
      setMessage(mode === "signup"
        ? "Account created. If email confirmation is enabled, check your inbox to confirm your address."
        : "Signed in successfully. Your account is ready.");
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="account-shell">
      <Link className="brand" href="/">INFINITE <span>TOURNAMENT</span></Link>
      <section className="account-card">
        <p className="eyebrow">YOUR PLACE IN THE ARENA</p>
        <h1>{mode === "signup" ? "Create writer account" : "Welcome back"}</h1>
        <p className="muted">Use an email address and password to access tournament features.</p>
        <div className="tabs">
          <button className={mode === "signup" ? "tab active" : "tab"} onClick={() => { setMode("signup"); setMessage(""); }}>Create account</button>
          <button className={mode === "login" ? "tab active" : "tab"} onClick={() => { setMode("login"); setMessage(""); }}>Sign in</button>
        </div>
        <form onSubmit={submit}>
          <label>Email address</label>
          <input type="email" autoComplete="email" required value={email} onChange={e => setEmail(e.target.value)} />
          <label>Password</label>
          <input type="password" autoComplete={mode === "signup" ? "new-password" : "current-password"} minLength={6} required value={password} onChange={e => setPassword(e.target.value)} />
          <button className="button button-primary full" disabled={busy}>{busy ? "Please wait…" : mode === "signup" ? "Create account" : "Sign in"}</button>
        </form>
        {message && <p className="notice" role="status">{message}</p>}
        <p className="small-note">Character registration, matchmaking, submissions, and voting will be added to the next build.</p>
      </section>
    </main>
  );
}
