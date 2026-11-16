import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import ErrorBoundary from "./ErrorBoundary";

// Islands are separate React roots: they share this module, hence one QueryClient.
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,
      gcTime: 1000 * 60 * 10,
    },
  },
});

interface IslandProvidersProps {
  children: ReactNode;
}

export default function IslandProviders({ children }: IslandProvidersProps) {
  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </ErrorBoundary>
  );
}
