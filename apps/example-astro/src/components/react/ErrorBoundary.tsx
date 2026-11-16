import { Component, type ErrorInfo, type ReactNode } from "react";

interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  failed: boolean;
}

/**
 * Catches render errors of an island so a failure in one of them shows a
 * message instead of leaving a hole in the page.
 */
export default class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { failed: false };

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("Island failed to render:", error, info.componentStack);
  }

  render() {
    if (!this.state.failed) return this.props.children;

    return (
      <div className="flex items-center justify-center p-8">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-red-600 mb-4">Oops! Something went wrong</h1>
          <p className="text-gray-600">Please try refreshing the page or contact support if the problem persists.</p>
        </div>
      </div>
    );
  }
}
