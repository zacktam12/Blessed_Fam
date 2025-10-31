declare module "https://esm.sh/@supabase/supabase-js@2.39.0" {
	// Minimal stub for `@supabase/supabase-js` so the TypeScript server resolves the remote import.
	// Provide only the methods used by your function to improve editor assistance.

	export type SupabaseClient = {
		auth: {
			getUser: (token: string) => Promise<{ data: { user: any } | null; error: any }>,
			admin: {
				createUser: (opts: any) => Promise<{ data: any; error: any }>
			}
		},
		from: (table: string) => any,
	};

	export function createClient(url: string, key: string, opts?: any): SupabaseClient;

	export default createClient;
}
