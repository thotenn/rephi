import { describePage, hasNextPage, hasPreviousPage, type PageMeta } from "~/lib/rephi";

interface PaginationProps {
  meta: PageMeta | undefined;
  onPageChange: (page: number) => void;
  busy?: boolean;
  label?: string;
}

export default function Pagination({ meta, onPageChange, busy = false, label = "Pagination" }: PaginationProps) {
  if (!meta || meta.total_pages <= 1) {
    return meta ? <p className="mt-4 text-sm text-gray-500">{describePage(meta)}</p> : null;
  }

  const buttonClass =
    "px-3 py-1.5 border border-gray-300 rounded-md text-sm text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed";

  return (
    <nav className="mt-4 flex items-center justify-between" aria-label={label}>
      <p className="text-sm text-gray-500" data-testid="page-summary">
        {describePage(meta)} · Page {meta.page} of {meta.total_pages}
      </p>
      <div className="flex gap-2">
        <button
          type="button"
          className={buttonClass}
          disabled={busy || !hasPreviousPage(meta)}
          onClick={() => onPageChange(meta.page - 1)}
        >
          Previous
        </button>
        <button
          type="button"
          className={buttonClass}
          disabled={busy || !hasNextPage(meta)}
          onClick={() => onPageChange(meta.page + 1)}
        >
          Next
        </button>
      </div>
    </nav>
  );
}
