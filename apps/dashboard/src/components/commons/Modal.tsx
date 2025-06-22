import { type ReactNode, MouseEvent, KeyboardEvent, useRef, useEffect } from "react";

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: ReactNode;
  className?: string;
  forceComplete?: boolean;
}

export default function Modal({
  isOpen,
  onClose,
  title,
  children,
  className,
  forceComplete = false,
}: ModalProps) {
  const dialogRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (isOpen && dialogRef.current) {
      dialogRef.current.focus();
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleClose = () => {
    if (!forceComplete) onClose();
  };

  const handleBackdropClick = (e: MouseEvent<HTMLDivElement>) => {
    if (e.target === e.currentTarget && !forceComplete) {
      onClose();
    }
  };

  function handleBackdropKeyDown(event: KeyboardEvent<HTMLDivElement>): void {
    if (event.key === "Escape" && !forceComplete) {
      onClose();
    }
  }
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-transparent backdrop-blur-xs"
      onClick={handleBackdropClick}
      onKeyDown={handleBackdropKeyDown}
      role="button"
      tabIndex={0}
      aria-label="Close modal"
      ref={dialogRef}
    >
      <div
        className={`bg-white rounded-lg shadow-lg max-w-lg w-full p-6 relative ${
          className || ""
        }`}
        role="dialog"
        tabIndex={-1}
      >
        <button
          className="absolute top-2 right-2 ml-3 mb-3 text-gray-400 hover:text-gray-600 disabled:opacity-50 text-4xl"
          onClick={handleClose}
          aria-label="Close modal"
          disabled={forceComplete}
        >
          &times;
        </button>
        {title && (
          <h2 className="text-xl font-semibold mt-2 mb-2 text-black">
            {title}
          </h2>
        )}
        <div>{children}</div>
      </div>
    </div>
  );
}
