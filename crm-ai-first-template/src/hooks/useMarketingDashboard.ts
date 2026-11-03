import { subDays, startOfMonth, endOfMonth, subMonths, differenceInDays, format } from 'date-fns';

export type DateRangePreset = 'today' | 'yesterday' | '7d' | '14d' | '30d' | '90d' | '6m' | '1y' | 'all' | 'this_month' | 'last_month' | 'custom';

export interface DateRange {
  from: Date;
  to: Date;
}

export function getDateRange(preset: DateRangePreset, custom?: DateRange): DateRange {
  const now = new Date();
  switch (preset) {
    case 'today':
      return { from: now, to: now };
    case 'yesterday': {
      const y = subDays(now, 1);
      return { from: y, to: y };
    }
    case '7d':
      return { from: subDays(now, 7), to: now };
    case '14d':
      return { from: subDays(now, 14), to: now };
    case '30d':
      return { from: subDays(now, 30), to: now };
    case '90d':
      return { from: subDays(now, 90), to: now };
    case '6m':
      return { from: subMonths(now, 6), to: now };
    case '1y':
      return { from: subMonths(now, 12), to: now };
    case 'all':
      // Antes de 2022 não existe dado em nenhuma das fontes; serve como "tudo".
      return { from: new Date(2022, 0, 1), to: now };
    case 'this_month':
      return { from: startOfMonth(now), to: now };
    case 'last_month': {
      const last = subMonths(now, 1);
      return { from: startOfMonth(last), to: endOfMonth(last) };
    }
    case 'custom':
      return custom || { from: subDays(now, 30), to: now };
    default:
      return { from: subDays(now, 30), to: now };
  }
}

export function getPreviousRange(range: DateRange): DateRange {
  const days = differenceInDays(range.to, range.from);
  return {
    from: subDays(range.from, days + 1),
    to: subDays(range.from, 1),
  };
}

