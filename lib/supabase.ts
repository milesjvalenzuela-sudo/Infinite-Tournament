import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(url || "https://example.supabase.co", key || "missing-key");

export async function currentUser() {
  const { data } = await supabase.auth.getUser();
  return data.user;
}

export function friendlyError(error: unknown) {
  if (error instanceof Error) return error.message;
  if (error && typeof error === "object") {
    const e = error as { message?: unknown; details?: unknown; hint?: unknown; code?: unknown };
    const message = typeof e.message === "string" ? e.message : "Database request failed.";
    const details = typeof e.details === "string" && e.details ? `\nDetails: ${e.details}` : "";
    const hint = typeof e.hint === "string" && e.hint ? `\nHint: ${e.hint}` : "";
    const code = typeof e.code === "string" && e.code ? `\nCode: ${e.code}` : "";
    return `${message}${details}${hint}${code}`;
  }
  return "Something went wrong. Please try again.";
}
