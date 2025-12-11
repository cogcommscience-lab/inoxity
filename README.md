# inoxity
A repository to share our open-source iOS research app that 1) collects Apple Health data through Apple Healthkit, 2) deploys EMA style surveys, and 3) allows for user media uploads to Supabase for secure data storage.

## Setup

### Configuration

This app requires Supabase credentials to be configured. For security, these are stored in a `Config.plist` file that is not committed to git.

**Initial Setup:**
1. Copy `Inoxity/Config.example.plist` to `Inoxity/Config.plist`
2. Open `Inoxity/Config.plist` and replace the placeholder values:
   - `SupabaseURL`: Your Supabase project URL
   - `SupabaseAnonKey`: Your Supabase anonymous/public key
3. Add `Config.plist` to your Xcode project:
   - In Xcode, right-click on the `Inoxity` folder
   - Select "Add Files to Inoxity..."
   - Select `Config.plist`
   - Make sure "Copy items if needed" is unchecked (file is already in the folder)
   - Make sure "Add to targets: Inoxity" is checked
   - Click "Add"

**Important:** 
- `Config.plist` is gitignored and should never be committed
- `Config.example.plist` is a template and is safe to commit
- If you need to rotate your Supabase keys, update `Config.plist` with the new values
