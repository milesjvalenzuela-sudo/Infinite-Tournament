 "use client";
import Link from "next/link";
import { useState } from "react";
import { supabase, friendlyError } from "@/lib/supabase";

export default function AccountPage() {
  const [mode,setMode] = useState<"signup"|"login">("signup");
  const [email,setEmail] = useState(""); const [password,setPassword] = useState("");
  const [message,setMessage] = useState(""); const [busy,setBusy] = useState(false);
  async function submit(e:React.FormEvent<HTMLFormElement>) {
    e.preventDefault(); setBusy(true); setMessage("");
    try {
      const result = mode === "signup"
        ? await supabase.auth.signUp({email,password,options:{emailRedirectTo:window.location.origin+"/account"}})
        : await supabase.auth.signInWithPassword({email,password});
      if(result.error) throw result.error;
      if(mode==="signup" && !result.data.session) setMessage("Account created. Check your email to confirm your address, then sign in.");
      else window.location.href="/characters";
    } catch(e) { setMessage(friendlyError(e)); } finally { setBusy(false); }
  }
  return <main className="narrow"><section className="panel form-panel">
    <p className="eyebrow">YOUR PLACE IN THE ARENA</p><h1>{mode==="signup"?"Create writer account":"Welcome back"}</h1>
    <div className="tabs"><button className={mode==="signup"?"active":""} onClick={()=>setMode("signup")}>Create account</button><button className={mode==="login"?"active":""} onClick={()=>setMode("login")}>Sign in</button></div>
    <form onSubmit={submit}><label>Email address</label><input type="email" required value={email} onChange={e=>setEmail(e.target.value)}/><label>Password</label><input type="password" minLength={6} required value={password} onChange={e=>setPassword(e.target.value)}/><button className="button primary full" disabled={busy}>{busy?"Please wait…":mode==="signup"?"Create account":"Sign in"}</button></form>
    {message&&<p className="notice">{message}</p>}<p className="muted tiny">After signing in, you'll be taken to your character dashboard.</p>
  </section></main>;
}
