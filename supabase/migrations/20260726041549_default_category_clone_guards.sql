do $$
begin
  if exists (
    select 1
    from public.transaction_splits split
    join public.transactions transaction on transaction.id = split.transaction_id
    where split.user_id is distinct from transaction.user_id
  ) then
    raise exception 'Existing transaction split owner does not match its transaction'
      using errcode = '23503';
  end if;
end;
$$;

create or replace function public.rewrite_legacy_category_insert()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  template public.categories%rowtype;
begin
  if new.user_id is null then
    return new;
  end if;

  if new.group_id is not null and exists (
    select 1
    from public.category_groups candidate
    where candidate.id = new.group_id
      and candidate.user_id is null
      and candidate.template_id is null
  ) then
    new.group_id := public.default_category_group_clone_id(
      new.user_id,
      new.group_id
    );
  end if;

  select * into template
  from public.categories candidate
  where candidate.id = new.id
    and candidate.user_id is null
    and candidate.template_id is null
    and candidate.is_default;

  if not found then
    return new;
  end if;

  new.id := public.default_category_clone_id(new.user_id, template.id);
  new.template_id := template.id;
  new.name := template.name;
  new.parent_id := case
    when template.parent_id is null then null
    else public.default_category_clone_id(new.user_id, template.parent_id)
  end;
  new.type := template.type;
  new."group" := template."group";
  new.group_id := public.default_category_group_clone_id(
    new.user_id,
    template.group_id
  );
  new.icon := template.icon;
  new.color := template.color;
  new.is_default := true;
  new.created_at := coalesce(new.created_at, now());
  return new;
end;
$$;

create or replace function public.rewrite_template_category_reference()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if tg_table_name = 'transaction_splits' and not exists (
    select 1
    from public.transactions transaction
    where transaction.id = new.transaction_id
      and transaction.user_id = new.user_id
  ) then
    raise exception 'Split transaction must have the same owner'
      using errcode = '23503';
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

drop trigger transaction_splits_10_rewrite_template_category
  on public.transaction_splits;
create trigger transaction_splits_10_rewrite_template_category
before insert or update of user_id, transaction_id, category_id
on public.transaction_splits
for each row execute function public.rewrite_template_category_reference();

notify pgrst, 'reload schema';
