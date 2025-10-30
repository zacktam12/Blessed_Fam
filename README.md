# BlessedFam – Flutter + Supabase Attendance & Performance Tracker

BlessedFam helps the Gospel Believers Bible Study Family track weekly attendance and celebrate spiritual consistency across: Family Attendance, Morning Prayer, Bible Study, and Saturday/Sunday Service.

## Highlights
- Role-based app (Admin/Member) with Supabase Auth
- Server-time attendance check-in (fair and tamper-proof)
- Weighted performance scoring with weekly winner and leaderboard (scaffolded)
- Beautiful Material 3 UI, light/dark themes, responsive
- Riverpod state management, GoRouter navigation

## Tech Stack
- Flutter 3
- supabase_flutter
- flutter_riverpod
- go_router
- google_fonts

## Project Structure (key files)
- `lib/main.dart` – App entry
- `lib/app.dart` – App widget, theme + router wiring
- `lib/core/app_router.dart` – GoRouter config (Splash → Login/Home)
- `lib/core/theme/app_theme.dart` – Material 3 light/dark themes
- `lib/core/providers/` – Supabase and Auth providers
- `lib/features/auth/` – Splash, Login
- `lib/features/home/` – Home with tabs (Leaderboard, Announcements, Profile)
- `supabase/schema.sql` – Database tables, policies, RPC `check_in`

## Setup

### Quick Start

1) **Install Flutter** and create a device/emulator.

2) **Create a Supabase project**
   - Get your `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the dashboard.

3) **Apply the database schema**
   - Open the SQL editor in Supabase and run the contents of `supabase/schema.sql`.
   - This includes RLS policies for all tables.

4) **Configure environment** (required for security)
   ```bash
   # Run app with environment variables
   flutter run \
     --dart-define=SUPABASE_URL=your_url \
     --dart-define=SUPABASE_ANON_KEY=your_anon_key
   ```
   
   ⚠️ **Note**: Never commit credentials. They are now removed from defaults.

5) **Create initial admin user**
   - Create a user in Supabase Auth (email/password).
   - Update `role = 'admin'` in the `public.users` table for admin features.

6) **Setup automated weekly performance** (optional)
   - Enable pg_cron extension in Supabase
   - Run `supabase/functions/setup_cron.sql`

For detailed deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Role-based UI
- Admin-only features (like `Admin Attendance`) are hidden for members and guarded in navigation. Ensure the `users.role` column is set accordingly.

## Weekly Performance
- The SQL function `public.compute_weekly_performance(week_start)` computes weekly totals and ranks using:
  - Base weight per session
  - Time bonus +1 if arrived on/before `sessions.start_time`, -1 if later than 15 minutes, 0 otherwise
- Seeded defaults: Morning Prayer 06:00, Bible Study 18:00, Family 19:00, Service not time-tracked.
- To compute this week’s snapshot, run in SQL:
```sql
select public.compute_weekly_performance(date_trunc('week', now())::date);
```

## Profile & Avatars
- Create a Supabase Storage bucket named `avatars` (public) and enable RLS as desired.
- The Profile tab lets members update display name and upload avatar (JPEG). Avatars are saved to `avatars/{userId}.jpg` and URL is stored in `users.profile_picture_url`.

## Push Notifications (optional)
This project includes FCM scaffolding for Android/iOS:
1) Create a Firebase project, enable Cloud Messaging.
2) Add platforms:
   - Android: add `google-services.json`, update `android/build.gradle` and app-level `build.gradle` per Firebase docs.
   - iOS: add `GoogleService-Info.plist`, enable push capabilities.
3) In Supabase, create Edge Function secret `FCM_SERVER_KEY` with your FCM server key.
4) Deploy Edge Function `send_push` and call it with tokens from `public.device_tokens`.
5) The app auto-registers device tokens at startup (see `notifications_provider.dart`).

Register tokens example (SQL):
```sql
select token from public.device_tokens;
```


## Admin Workflow (scaffold)
- Use RPC `public.check_in(user_id, session_id, date)` to mark Present. It records server `now()` for time-tracked sessions.
- Weekly performance computation is planned via SQL/Edge Function (to be wired to UI in subsequent steps).

## Development
```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Next Steps (planned)
- Admin Attendance screen (filter by session/date, tap to check-in)
- Leaderboard with weekly winner highlight
- Announcements CRUD (admin) + feed (members)
- Profile edit (display name, avatar upload to Supabase Storage)
- Edge Function/cron for weekly performance snapshot
