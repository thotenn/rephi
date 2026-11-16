// Same formats as the server (Role / Permission changesets).
const SEGMENT = "[a-z0-9]+(?:[_-][a-z0-9]+)*";
const ROLE_SLUG = new RegExp(`^${SEGMENT}$`);
const PERMISSION_SLUG = new RegExp(`^${SEGMENT}(?::${SEGMENT})+$`);
const MAX_SLUG_LENGTH = 100;

export function validateRoleSlug(slug: string): string | null {
  if (!slug) return "can't be blank";
  if (slug.length > MAX_SLUG_LENGTH) return `should be at most ${MAX_SLUG_LENGTH} characters`;
  return ROLE_SLUG.test(slug) ? null : "must be lowercase letters and digits, separated by - or _";
}

export function validatePermissionSlug(slug: string): string | null {
  if (!slug) return "can't be blank";
  if (slug.length > MAX_SLUG_LENGTH) return `should be at most ${MAX_SLUG_LENGTH} characters`;
  return PERMISSION_SLUG.test(slug) ? null : "must look like category:action (e.g. users:edit)";
}

export function roleSlugFromName(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

/** "Edit Users" -> "edit:users": the first word becomes the action. */
export function permissionSlugFromName(name: string): string {
  const words = roleSlugFromName(name).split("_").filter(Boolean);
  if (words.length < 2) return words.join("");
  const [action, ...category] = words;
  return `${category.join("_")}:${action}`;
}
