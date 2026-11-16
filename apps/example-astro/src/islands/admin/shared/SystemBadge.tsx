/** Marks a seeded role or permission (not deletable, slug locked). */
export default function SystemBadge() {
  return (
    <span
      className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-200 text-gray-700"
      title="Created by the seeds: it cannot be deleted and its slug cannot change"
    >
      System
    </span>
  );
}
