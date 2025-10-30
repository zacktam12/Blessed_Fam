// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// Get environment variables
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing required environment variables");
}

// Create Supabase client with service role key for admin access
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

/**
 * Compute weekly performance scores for all users.
 * This function can be triggered manually via HTTP or by a cron job.
 * 
 * Query parameters:
 * - week_start: Optional ISO date string (YYYY-MM-DD). Defaults to current Monday.
 * 
 * Example:
 * POST /compute_weekly_performance?week_start=2025-01-27
 */
serve(async (req) => {
  try {
    // Parse query parameters
    const url = new URL(req.url);
    let weekStartDate: string;

    const weekStartParam = url.searchParams.get("week_start");
    if (weekStartParam) {
      // Validate the date format
      const date = new Date(weekStartParam);
      if (isNaN(date.getTime())) {
        return new Response(
          JSON.stringify({ error: "Invalid week_start date format. Use YYYY-MM-DD" }),
          { status: 400, headers: { "content-type": "application/json" } }
        );
      }
      weekStartDate = weekStartParam;
    } else {
      // Calculate the Monday of the current week
      const now = new Date();
      const dayOfWeek = now.getDay(); // 0 = Sunday, 1 = Monday, etc.
      const daysToMonday = (dayOfWeek === 0 ? -6 : 1 - dayOfWeek);
      const monday = new Date(now);
      monday.setDate(now.getDate() + daysToMonday);
      weekStartDate = monday.toISOString().split("T")[0]; // YYYY-MM-DD format
    }

    console.log(`Computing weekly performance for week starting: ${weekStartDate}`);

    // Call the PostgreSQL function to compute performance
    const { error: rpcError } = await supabase.rpc("compute_weekly_performance", {
      p_week_start: weekStartDate,
    });

    if (rpcError) {
      console.error("RPC Error:", rpcError);
      return new Response(
        JSON.stringify({ 
          error: "Failed to compute performance", 
          details: rpcError.message 
        }),
        { status: 500, headers: { "content-type": "application/json" } }
      );
    }

    // Fetch the computed results to return summary
    const { data: results, error: fetchError } = await supabase
      .from("performance")
      .select("user_id, total_score, rank")
      .eq("week_start_date", weekStartDate)
      .order("rank", { ascending: true });

    if (fetchError) {
      console.error("Fetch Error:", fetchError);
      return new Response(
        JSON.stringify({ 
          warning: "Computed but failed to fetch results", 
          details: fetchError.message 
        }),
        { status: 200, headers: { "content-type": "application/json" } }
      );
    }

    console.log(`Successfully computed performance for ${results?.length || 0} users`);

    return new Response(
      JSON.stringify({
        success: true,
        week_start_date: weekStartDate,
        users_computed: results?.length || 0,
        top_3: results?.slice(0, 3).map((r) => ({
          user_id: r.user_id,
          score: r.total_score,
          rank: r.rank,
        })) || [],
      }),
      { 
        status: 200, 
        headers: { "content-type": "application/json" } 
      }
    );
  } catch (error: any) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({ 
        error: "Internal server error", 
        details: error.message 
      }),
      { status: 500, headers: { "content-type": "application/json" } }
    );
  }
});


