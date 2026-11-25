-- Drop existing device_tokens table if it exists (safety migration)
DROP TABLE IF EXISTS public.device_tokens CASCADE;
