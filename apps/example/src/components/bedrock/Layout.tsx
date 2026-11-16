import type { ReactNode } from "react";
import Header from "./Header";

interface LayoutProps {
  children: ReactNode;
  title?: string;
}

export default function Layout({ children, title }: LayoutProps) {
  return (
    <div className="min-h-screen bg-gray-50">
      <Header title={title} />
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          {children}
        </div>
      </main>
    </div>
  );
}
