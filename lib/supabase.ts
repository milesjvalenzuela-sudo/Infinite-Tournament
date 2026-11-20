import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(url || "https://example.supabase.co", key || "missing-key");

export async function currentUser() {
  const { data } = await supabase.auth.getUser();
  return data.user;
}

export function friendlyError(error: unknown) {
  return error instanceof Error ? error.message : "Something went wrong. Please try again.";
}
