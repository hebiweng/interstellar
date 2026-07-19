import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host = requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host") ?? "localhost:3001";
  const localHost = /^(localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$/.test(host);
  const protocol = requestHeaders.get("x-forwarded-proto") ?? (localHost ? "http" : "https");
  const baseUrl = new URL(`${protocol}://${host}`);
  const socialImage = new URL("/og.png", baseUrl).toString();

  return {
    metadataBase: baseUrl,
    title: "Interstellar · 专业占星研究工作台",
    description: "可复现、可验证、可追溯的专业西方占星计算与研究工作台。",
    applicationName: "Interstellar",
    icons: { icon: "/favicon.svg" },
    openGraph: {
      title: "Interstellar · Professional Astrology Workspace",
      description: "Professional astrology calculation, visualization, and evidence workspace.",
      type: "website",
      url: baseUrl,
      images: [{ url: socialImage, width: 1536, height: 1024, alt: "Interstellar professional astrology workspace" }],
    },
    twitter: {
      card: "summary_large_image",
      title: "Interstellar · Professional Astrology Workspace",
      description: "Professional astrology calculation, visualization, and evidence workspace.",
      images: [socialImage],
    },
  };
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const themeBootstrap = `(() => { try { const saved = localStorage.getItem('interstellar.theme'); document.documentElement.dataset.theme = saved === 'light' ? 'light' : 'dark'; } catch (_) { document.documentElement.dataset.theme = 'dark'; } })();`;
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <head><script dangerouslySetInnerHTML={{ __html: themeBootstrap }} /></head>
      <body>{children}</body>
    </html>
  );
}
