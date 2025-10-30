// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing required environment variables");
}

// Create Supabase admin client
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

/**
 * Admin-only function to create new users
 * Requires authentication and admin role
 */
serve(async (req) => {
  // Check authentication
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Missing authorization header" }),
      { status: 401, headers: { "content-type": "application/json" } }
    );
  }

  // Verify the calling user is an admin
  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);
  
  if (authError || !user) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { "content-type": "application/json" } }
    );
  }

  // Check if user is admin
  const { data: profile, error: profileError } = await supabaseAdmin
    .from("users")
    .select("role")
    .eq("id", user.id)
    .single();

  if (profileError || profile?.role !== "admin") {
    return new Response(
      JSON.stringify({ error: "Admin access required" }),
      { status: 403, headers: { "content-type": "application/json" } }
    );
  }

  // Parse request body
  const { email, password, name, role } = await req.json();

  // Validate input
  if (!email || !password || !name || !role) {
    return new Response(
      JSON.stringify({ error: "Missing required fields: email, password, name, role" }),
      { status: 400, headers: { "content-type": "application/json" } }
    );
  }

  if (!["admin", "member"].includes(role)) {
    return new Response(
      JSON.stringify({ error: "Invalid role. Must be 'admin' or 'member'" }),
      { status: 400, headers: { "content-type": "application/json" } }
    );
  }

  try {
    // Create the user
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name },
    });

    if (createError) {
      console.error("Error creating user:", createError);
      return new Response(
        JSON.stringify({ error: createError.message }),
        { status: 400, headers: { "content-type": "application/json" } }
      );
    }

    if (!newUser.user) {
      return new Response(
        JSON.stringify({ error: "Failed to create user" }),
        { status: 500, headers: { "content-type": "application/json" } }
      );
    }

    // Update the user's profile in public.users table
    const { error: updateError } = await supabaseAdmin
      .from("users")
      .update({ name, role })
      .eq("id", newUser.user.id);

    if (updateError) {
      console.error("Error updating profile:", updateError);
      // User was created but profile update failed
      return new Response(
        JSON.stringify({ 
          warning: "User created but profile update failed",
          user_id: newUser.user.id,
          error: updateError.message 
        }),
        { status: 207, headers: { "content-type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        user_id: newUser.user.id,
        email: newUser.user.email,
        role,
      }),
      { status: 200, headers: { "content-type": "application/json" } }
    );
  } catch (error: any) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 500, headers: { "content-type": "application/json" } }
    );
  }
});
