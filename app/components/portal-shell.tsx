"use client";

import { useEffect, useState, type ReactNode } from "react";
import Link from "next/link";

import styles from "./portal-shell.module.css";

type PortalShellProps = {
  active: "workspace" | "analysis" | "technique" | "objects" | "account" | "admin";
  eyebrow: string;
  title: string;
  description: string;
  headerAction?: ReactNode;
  children: ReactNode;
};

const navigation = [
  { id: "workspace", label: "工作台", href: "/" },
  { id: "analysis", label: "分析中心", href: "/?analysis-center=1" },
  { id: "technique", label: "技法排盘", href: "/?new-analysis=1&entry=technique" },
  { id: "objects", label: "对象库", href: "/objects" },
] as const;

export function PortalShell({ active, eyebrow, title, description, headerAction, children }: PortalShellProps) {
  const [theme, setTheme] = useState<"dark" | "light">("dark");

  useEffect(() => {
    queueMicrotask(() => {
      const stored = window.localStorage.getItem("interstellar.theme");
      const next = stored === "light" ? "light" : "dark";
      document.documentElement.dataset.theme = next;
      setTheme(next);
    });
  }, []);

  function toggleTheme() {
    const next = theme === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    window.localStorage.setItem("interstellar.theme", next);
    setTheme(next);
  }

  return (
    <div className={styles.shell}>
      <header className={styles.header}>
        <Link className={styles.brand} href="/" aria-label="返回 Interstellar 工作台">
          <span className={styles.mark}>✦</span>
          <span className={styles.brandText}>
            <b>INTERSTELLAR</b>
            <small>PROFESSIONAL ASTROLOGY</small>
          </span>
        </Link>
        <nav className={styles.nav} aria-label="全局导航">
          {navigation.map((item) => (
            <Link key={item.id} href={item.href} data-active={active === item.id}>{item.label}</Link>
          ))}
          {active === "admin" && <Link href="/admin" data-active="true">后台管理</Link>}
        </nav>
        <div className={styles.actions}>
          <Link className={styles.secondary} href="/account">账户中心</Link>
          <button
            className={styles.theme}
            type="button"
            onClick={toggleTheme}
            aria-label={theme === "dark" ? "切换到浅色主题" : "切换到深色主题"}
            title={theme === "dark" ? "当前深色主题" : "当前浅色主题"}
          >
            {theme === "dark" ? "☀" : "☾"}
          </button>
          <Link className={styles.primary} href="/?new-analysis=1">＋ 新建分析</Link>
        </div>
      </header>
      <main className={styles.main}>
        <header className={styles.pageHeader}>
          <div>
            <span className={styles.eyebrow}>{eyebrow}</span>
            <h1>{title}</h1>
            <p>{description}</p>
          </div>
          {headerAction}
        </header>
        {children}
      </main>
    </div>
  );
}

export { styles as portalStyles };
