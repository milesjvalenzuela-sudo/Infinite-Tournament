 "use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

export function SiteNav() {
  const [email, setEmail] = useState<string | null>(null);
  useEffect(() => {
    supabase.auth.getUser().then(({data}) => setEmail(data.user?.email ?? null));
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => setEmail(session?.user?.email ?? null));
    return () => listener.subscription.unsubscribe();
  }, []);
  async function signOut() { await supabase.auth.signOut(); window.location.href = "/"; }
  return <header className="topbar">
    <Link className="brand" href="/">INFINITE <span>TOURNAMENT</span></Link>
    <nav>
      <Link href="/characters">Characters</Link><Link href="/matches">Matches</Link>
      <Link href="/vote">Vote</Link><Link href="/brackets">Brackets</Link><Link href="/archive">Canon</Link>
      {email ? <button className="nav-button" onClick={signOut}>Sign out</button> : <Link href="/account">Writer sign in</Link>}
    </nav>
  </header>;
}
