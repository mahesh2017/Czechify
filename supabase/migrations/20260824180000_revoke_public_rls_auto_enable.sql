-- This platform-provided event-trigger helper runs as its owner when DDL is
-- executed. API roles never need to invoke it through PostgREST.
revoke all on function public.rls_auto_enable() from public, anon, authenticated;
