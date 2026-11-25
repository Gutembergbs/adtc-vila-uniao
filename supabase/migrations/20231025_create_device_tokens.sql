CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- ensure uuid_generate_v4 exists
-- Migration: create device_tokens table for push notification tokens
-- Store FCM/APNs tokens per user
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token text NOT NULL,
    platform text NOT NULL CHECK (platform IN ('android', 'ios')),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Index for quick lookup by user
CREATE INDEX idx_device_tokens_user_id ON public.device_tokens(user_id);

-- Trigger to update updated_at on row change
CREATE OR REPLACE FUNCTION public.set_device_token_timestamp()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_device_token_timestamp
BEFORE UPDATE ON public.device_tokens
FOR EACH ROW EXECUTE FUNCTION public.set_device_token_timestamp();
