create or replace function public.rewrite_template_category_reference()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if tg_table_name = 'transaction_splits' then
    if not exists (
      select 1
      from public.transactions transaction
      where transaction.id = new.transaction_id
        and transaction.user_id = new.user_id
    ) then
      raise exception 'Split transaction must have the same owner'
        using errcode = '23503';
    end if;
  end if;

  if new.category_id is null then
    return new;
  end if;

  if exists (
    select 1 from public.categories template
    where template.id = new.category_id
      and template.user_id is null
      and template.template_id is null
      and template.is_default
  ) then
    new.category_id := public.default_category_clone_id(
      new.user_id,
      new.category_id
    );
  end if;

  if not exists (
    select 1 from public.categories category
    where category.id = new.category_id
      and category.user_id = new.user_id
  ) then
    raise exception 'Transaction category must have the same owner'
      using errcode = '23503';
  end if;
  return new;
end;
$$;

notify pgrst, 'reload schema';
