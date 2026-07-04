import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Lucid AI — Infinite worlds. Infinite stories. Infinite you.",
  description: "The AI-powered interactive storytelling platform where every choice changes the world.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col bg-ink bg-runes">{children}</body>
    </html>
  );
}
