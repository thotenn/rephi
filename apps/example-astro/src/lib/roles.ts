/** Badge colors of the seeded roles; any other role is gray. */
export function roleBadgeClass(roleSlug: string): string {
  switch (roleSlug) {
    case "admin":
      return "bg-red-100 text-red-800";
    case "manager":
      return "bg-yellow-100 text-yellow-800";
    case "user":
      return "bg-green-100 text-green-800";
    default:
      return "bg-gray-100 text-gray-800";
  }
}
