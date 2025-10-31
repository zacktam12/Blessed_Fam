// Minimal ambient declaration to satisfy TypeScript/TS Server when Deno types
// or the VS Code Deno extension are not installed/enabled.
// This intentionally uses `any` for flexibility; replace with stricter types
// if you want full type-safety.

declare const Deno: {
  env: {
    get(name: string): string | undefined;
  };
  // Add other Deno APIs you use here if desired
};
