declare module "https://deno.land/std@0.177.0/http/server.ts" {
  // Minimal stub for Deno http server `serve` to satisfy the TypeScript server in VS Code.
  export function serve(handler: (req: Request) => Response | Promise<Response>): void;

  export interface ServerOptions {
    port?: number;
  }

  export default serve;
}
