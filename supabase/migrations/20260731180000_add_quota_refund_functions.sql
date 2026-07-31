-- Add quota refund functions for AI and speech services.
--
-- When an upstream provider (DeepSeek, OpenAI Whisper) returns an error or
-- times out, the learner's daily quota should not be consumed.  These
-- functions decrement the daily counter back, so a failed call does not
-- waste the learner's allowance.

-- Refund one AI daily quota consumption for a user.
CREATE OR REPLACE FUNCTION refund_ai_daily_quota(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Only refund if a quota row exists for today; never create one.
  UPDATE public.ai_daily_quota
  SET requests_used = GREATEST(requests_used - 1, 0)
  WHERE user_id = p_user_id
    AND quota_date = CURRENT_DATE;
END;
$$;

-- Refund one speech service daily quota consumption for a user.
CREATE OR REPLACE FUNCTION refund_service_daily_quota(
  p_service text,
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.service_daily_quota
  SET requests_used = GREATEST(requests_used - 1, 0)
  WHERE user_id = p_user_id
    AND service = p_service
    AND quota_date = CURRENT_DATE;
END;
$$;

COMMENT ON FUNCTION public.refund_ai_daily_quota(uuid) IS
  'Decrements the AI daily quota counter by 1, used when an upstream call fails so the learner does not lose their allowance.';
COMMENT ON FUNCTION public.refund_service_daily_quota(text, uuid) IS
  'Decrements the speech service daily quota counter by 1, used when Whisper returns an error so the learner does not lose their allowance.';

-- These functions are internal RPCs called only by Edge Functions using the
-- service-role client. PostgreSQL grants EXECUTE to PUBLIC by default, so
-- revoke it explicitly to prevent learners refunding arbitrary quota rows.
REVOKE ALL ON FUNCTION public.refund_ai_daily_quota(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refund_service_daily_quota(text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refund_ai_daily_quota(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.refund_service_daily_quota(text, uuid) TO service_role;
