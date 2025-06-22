
interface AccessDeniedProps {
    title?: string,
    message?: string,
    buttonText?: string,
    buttonFunction?: () => void,
}

export function AccessDenied ({ 
    title = "Access Denied", 
    message = "You don't have permission to access this resource.", 
    buttonText = "Go Back", 
    buttonFunction = () => window.history.back() 
}: AccessDeniedProps) {
    return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="max-w-md w-full bg-white shadow rounded-lg p-6">
            <div className="text-center">
            <svg
                className="mx-auto h-12 w-12 text-red-500"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
            >
                <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                />
            </svg>
            <h3 className="mt-2 text-sm font-medium text-gray-900">{title}</h3>
            <p className="mt-1 text-sm text-gray-500">
                {message}
            </p>
            <div className="mt-6">
                <button
                onClick={buttonFunction}
                className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200"
                >
                {buttonText}
                </button>
            </div>
            </div>
        </div>
        </div>
    );
}