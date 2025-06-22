import { ReactNode } from "react";

interface Column {
  key: string;
  label: string;
  className?: string;
}

interface TableCommonProps {
  columns: Column[];
  children: ReactNode;
  className?: string;
}

export default function TableCommon({ columns, children, className = "" }: TableCommonProps) {
  return (
    <div className={`bg-white rounded-lg shadow overflow-hidden ${className}`.trim()}>
      <table className="w-full">
        <thead className="bg-gray-50">
          <tr>
            {columns.map((column) => (
              <th
                key={column.key}
                className={`px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase ${column.className || ""}`}
              >
                {column.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {children}
        </tbody>
      </table>
    </div>
  );
}