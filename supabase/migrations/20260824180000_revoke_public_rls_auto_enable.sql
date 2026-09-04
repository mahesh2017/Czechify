-- This platform-provided event-trigger helper runs as its owner when DDL is
-- executed. API roles never need to invoke it through PostgREST.
-- Clean local/CI databases do not include the platform-managed helper.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end;
$$;
