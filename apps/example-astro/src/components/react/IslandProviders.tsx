import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import ErrorBoundary from "./ErrorBoundary";

/**
 * Every Astro island is its own React root, so React context does not flow from
 * one island to another. Module state does: all islands on a page import this
 * same module, hence the same `QueryClient`.
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      gcTime: 1000 * 60 * 10, // 10 minutes
    },
  },
});

interface IslandProvidersProps {
  children: ReactNode;
}

/** Wraps the content of an island with the providers the SPA has at its root. */
export default function IslandProviders({ children }: IslandProvidersProps) {
  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </ErrorBoundary>
  );
}
