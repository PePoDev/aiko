import { getFirestore } from 'firebase-admin/firestore';
import Decimal from 'decimal.js';

type Row = Record<string, any>;
const allowed = new Set(['aiko_account_summary', 'aiko_budget_status', 'aiko_spending_by_category', 'aiko_cashflow_summary', 'aiko_recent_transactions', 'aiko_goal_progress']);
const number = (value: unknown) => new Decimal(String(value ?? '0'));

export function summarize(name: string, args: Row, accounts: Row[], transactions: Row[], categories: Row[]): unknown {
  if (!allowed.has(name)) throw new Error('Unknown financial tool.');
  const categoryNames = new Map(categories.map(c => [c.id, c.name]));
  const datesRequired = ['aiko_budget_status', 'aiko_spending_by_category', 'aiko_cashflow_summary'].includes(name);
  if (datesRequired && (!/^\d{4}-\d{2}-\d{2}$/.test(args.start_date) || !/^\d{4}-\d{2}-\d{2}$/.test(args.end_date) || args.start_date > args.end_date)) {
    throw new Error('A valid inclusive date range is required.');
  }
  const txs = datesRequired ? transactions.filter(t => String(t.date).slice(0, 10) >= args.start_date && String(t.date).slice(0, 10) <= args.end_date) : transactions;
  const active = accounts.filter(a => a.is_active);
  switch (name) {
    case 'aiko_account_summary': {
      const totals: Record<string, Decimal> = {};
      // Balances are signed: debts (a used card, a loan) are already negative.
      for (const account of active) {
        if (!account.include_in_net_worth || account.type === 'goal') continue;
        totals[account.currency] = (totals[account.currency] ?? new Decimal(0)).plus(number(account.current_balance));
      }
      return { net_worth_by_currency: Object.fromEntries(Object.entries(totals).map(([k, v]) => [k, v.toFixed()])),
        accounts: active.map(a => ({name: a.name, type: a.type, currency: a.currency, balance: a.current_balance})) };
    }
    case 'aiko_goal_progress': return active.filter(a => a.type === 'goal' && a.goal_target_amount)
      .slice(0, 50).map(a => ({name: a.name, currency: a.currency, current_amount: a.current_balance, target_amount: a.goal_target_amount,
        pct: number(a.goal_target_amount).gt(0) ? number(a.current_balance).div(a.goal_target_amount).toFixed(4) : '0', target_date: a.goal_target_date}));
    case 'aiko_recent_transactions': return [...txs].sort((a,b) => String(b.date).localeCompare(a.date))
      .slice(0, Math.min(50, Math.max(1, Number(args.max_rows) || 20)))
      .map(t => ({tx_date: t.date, type: t.type, amount: t.amount, currency: t.currency, merchant: t.merchant, category: categoryNames.get(t.category_id) ?? 'Uncategorized'}));
    case 'aiko_cashflow_summary': {
      const totals: Record<string, {income: Decimal; expense: Decimal}> = {};
      for (const tx of txs) {
        if (!['income', 'expense'].includes(tx.type)) continue;
        totals[tx.currency] ??= {income: new Decimal(0), expense: new Decimal(0)};
        if (tx.type === 'income') totals[tx.currency].income = totals[tx.currency].income.plus(number(tx.amount));
        else totals[tx.currency].expense = totals[tx.currency].expense.plus(number(tx.amount));
      }
      return Object.entries(totals).map(([currency, t]) => ({currency, income:t.income.toFixed(), expense:t.expense.toFixed(), net:t.income.minus(t.expense).toFixed()}));
    }
    case 'aiko_budget_status': return categories.filter(c => c.is_active && c.budget_enabled && c.budget_amount)
      .slice(0,50).map(c => ({name:c.name, budget_limit:c.budget_amount, currency:c.budget_currency,
        spent: txs.filter(t => t.type === 'expense' && t.category_id === c.id && t.currency === c.budget_currency)
          .reduce((sum,t) => sum.plus(number(t.amount)),new Decimal(0)).toFixed()}));
    default: {
      const totals = new Map<string, {category: string; currency: string; total: Decimal}>();
      for (const tx of txs.filter(t => t.type === 'expense')) {
        const key = `${tx.category_id}:${tx.currency}`;
        const total = totals.get(key) ?? {category: categoryNames.get(tx.category_id) ?? 'Uncategorized', currency:tx.currency,total:new Decimal(0)};
        total.total = total.total.plus(number(tx.amount)); totals.set(key,total);
      }
      return [...totals.values()].sort((a,b) => b.total.cmp(a.total)).slice(0,50).map(t => ({...t,total:t.total.toFixed()}));
    }
  }
}

const validRange = (args: Row) => /^\d{4}-\d{2}-\d{2}$/.test(args.start_date) && /^\d{4}-\d{2}-\d{2}$/.test(args.end_date) && args.start_date <= args.end_date;
const dayAfter = (date: string) => new Date(Date.parse(`${date}T00:00:00Z`) + 86400000).toISOString().slice(0, 10);

// Reads only what each tool needs (billed per document) and memoizes it for one
// chat request, so repeated or overlapping tool calls don't re-read the ledger.
// `date` is an ISO string, so a date range is a string range on one field and
// needs no composite index.
export class FinanceReader {
  documentsRead = 0;
  private readonly memo = new Map<string, Promise<Row[]>>();
  private readonly categories = new Map<string, Row | undefined>();
  constructor(private readonly uid: string) {}
  private collection(name: string) { return getFirestore().collection('users').doc(this.uid).collection(name); }
  private once(key: string, query: () => FirebaseFirestore.Query): Promise<Row[]> {
    if (!this.memo.has(key)) this.memo.set(key, query().get().then(s => { this.documentsRead += s.size; return s.docs.map(d => d.data()); }));
    return this.memo.get(key)!;
  }
  accounts() { return this.once('accounts', () => this.collection('accounts')); }
  budgetedCategories() { return this.once('budgeted', () => this.collection('categories').where('budget_enabled', '==', true)); }
  transactionsBetween(start: string, end: string) {
    return this.once(`range:${start}:${end}`, () => this.collection('transactions').where('date', '>=', start).where('date', '<', dayAfter(end)));
  }
  recentTransactions(limit: number) { return this.once(`recent:${limit}`, () => this.collection('transactions').orderBy('date', 'desc').limit(limit)); }
  async categoriesById(ids: unknown[]): Promise<Row[]> {
    const missing = [...new Set(ids.filter((id): id is string => typeof id === 'string' && id.length > 0 && !id.includes('/')))].filter(id => !this.categories.has(id));
    if (missing.length) {
      const docs = await getFirestore().getAll(...missing.map(id => this.collection('categories').doc(id)));
      this.documentsRead += docs.length;
      docs.forEach((doc, i) => this.categories.set(missing[i], doc.data()));
    }
    return ids.map(id => this.categories.get(String(id))).filter((c): c is Row => !!c);
  }
}

export async function financeTool(uid: string, name: string, args: Row, reader = new FinanceReader(uid)): Promise<unknown> {
  if (!allowed.has(name)) throw new Error('Unknown financial tool.');
  switch (name) {
    case 'aiko_account_summary':
    case 'aiko_goal_progress':
      return summarize(name, args, await reader.accounts(), [], []);
    case 'aiko_recent_transactions': {
      const txs = await reader.recentTransactions(Math.min(50, Math.max(1, Number(args.max_rows) || 20)));
      return summarize(name, args, [], txs, await reader.categoriesById(txs.map(t => t.category_id)));
    }
  }
  if (!validRange(args)) throw new Error('A valid inclusive date range is required.');
  const txs = await reader.transactionsBetween(args.start_date, args.end_date);
  switch (name) {
    case 'aiko_cashflow_summary': return summarize(name, args, [], txs, []);
    case 'aiko_budget_status': return summarize(name, args, [], txs, await reader.budgetedCategories());
    default: return summarize(name, args, [], txs, await reader.categoriesById(txs.filter(t => t.type === 'expense').map(t => t.category_id)));
  }
}
