delete from public.categories c
where c.parent_id is null
  and c.icon = 'category'
  and c.color = '#3B82F6'
  and c.budget_enabled = true
  and c.is_default = false
  and c.is_active = true
  and (
    (c.name = 'Salary' and c.type = 'income' and c."group" = 'custom')
    or
    (c.name = 'Food and Dining' and c.type = 'expense' and c."group" = 'needs')
  )
  and not exists (
    select 1
    from public.transactions t
    where t.category_id = c.id
  )
  and not exists (
    select 1
    from public.transaction_splits ts
    where ts.category_id = c.id
  )
  and not exists (
    select 1
    from public.transaction_rules tr
    where tr.target_category_id = c.id
  )
  and not exists (
    select 1
    from public.budgets b
    where b.category_id = c.id
  );
