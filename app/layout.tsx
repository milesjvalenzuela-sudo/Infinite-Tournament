import type { Metadata } from "next";
import "./globals.css";
import { SiteNav } from "./site-nav";

export const metadata: Metadata = {
  title: "The Infinite Tournament",
  description: "Original characters. Writer-crafted battles. Public voting decides canon.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body><SiteNav />{children}</body></html>;
}
