import { getMeteorologicalSeason, getUpcomingOccasions, type OccasionCalendarEntry } from '../occasions';

describe('getMeteorologicalSeason', () => {
  it.each([
    [0, 'winter'], // January
    [1, 'winter'], // February
    [2, 'spring'], // March
    [4, 'spring'], // May
    [5, 'summer'], // June
    [7, 'summer'], // August
    [8, 'fall'], // September
    [10, 'fall'], // November
    [11, 'winter'], // December
  ])('month index %i is %s in the Northern hemisphere', (monthIndex, expected) => {
    const date = new Date(2025, monthIndex, 15);
    expect(getMeteorologicalSeason(date, 40)).toBe(expected);
  });

  it('flips the season for the Southern hemisphere', () => {
    const januaryDate = new Date(2025, 0, 15);
    expect(getMeteorologicalSeason(januaryDate, 40)).toBe('winter'); // Northern
    expect(getMeteorologicalSeason(januaryDate, -33)).toBe('summer'); // Southern (e.g. São Paulo)
  });

  it('defaults to the Northern hemisphere when latitude is null', () => {
    const juneDate = new Date(2025, 5, 15);
    expect(getMeteorologicalSeason(juneDate, null)).toBe('summer');
  });
});

describe('getUpcomingOccasions', () => {
  const valentinesDay: OccasionCalendarEntry = {
    slug: 'valentines_day',
    name: "Valentine's Day",
    month: 2,
    day: 14,
    isMovable: false,
    occasionSlug: 'date_night',
    leadDays: 5,
  };

  it('detects a fixed-date holiday within its lead window, with correct daysUntil', () => {
    const today = new Date(2025, 1, 10); // Feb 10 — 4 days before Feb 14
    const upcoming = getUpcomingOccasions([valentinesDay], today);

    expect(upcoming).toHaveLength(1);
    expect(upcoming[0].occasionSlug).toBe('date_night');
    expect(upcoming[0].daysUntil).toBe(4);
  });

  it('gives full weight (1.0) on the day itself', () => {
    const today = new Date(2025, 1, 14); // the holiday itself
    const upcoming = getUpcomingOccasions([valentinesDay], today);
    expect(upcoming[0].daysUntil).toBe(0);
    expect(upcoming[0].weight).toBeCloseTo(1, 5);
  });

  it('does not detect a holiday outside its lead window', () => {
    const today = new Date(2025, 0, 1); // Jan 1 — 44 days before Feb 14, well outside a 5-day window
    expect(getUpcomingOccasions([valentinesDay], today)).toHaveLength(0);
  });

  it('does not detect a holiday that has already passed this year (and is far from next year\'s)', () => {
    const today = new Date(2025, 2, 1); // March 1 — after this year's Feb 14, and >5 days from next Feb 14
    expect(getUpcomingOccasions([valentinesDay], today)).toHaveLength(0);
  });

  it('handles a lead window spanning the year boundary (checking December for a January holiday)', () => {
    const newYearsDay: OccasionCalendarEntry = {
      slug: 'new_years_day',
      name: "New Year's Day",
      month: 1,
      day: 1,
      isMovable: false,
      occasionSlug: 'cozy_home',
      leadDays: 3,
    };
    const today = new Date(2025, 11, 30); // Dec 30 — 2 days before Jan 1, 2026
    const upcoming = getUpcomingOccasions([newYearsDay], today);

    expect(upcoming).toHaveLength(1);
    expect(upcoming[0].daysUntil).toBe(2);
  });

  it('resolves the movable holiday "easter" to its real Gregorian-calculated date', () => {
    const easter: OccasionCalendarEntry = {
      slug: 'easter',
      name: 'Easter Sunday',
      month: null,
      day: null,
      isMovable: true,
      occasionSlug: 'festive',
      leadDays: 5,
    };
    // Easter 2025 is April 20.
    const today = new Date(2025, 3, 18); // April 18 — 2 days before
    const upcoming = getUpcomingOccasions([easter], today);

    expect(upcoming).toHaveLength(1);
    expect(upcoming[0].daysUntil).toBe(2);
  });

  it('resolves "mothers_day" to the 2nd Sunday of May', () => {
    const mothersDay: OccasionCalendarEntry = {
      slug: 'mothers_day',
      name: "Mother's Day",
      month: null,
      day: null,
      isMovable: true,
      occasionSlug: 'festive',
      leadDays: 5,
    };
    // Mother's Day 2024 is May 12.
    const onTheDay = new Date(2024, 4, 12);
    const upcoming = getUpcomingOccasions([mothersDay], onTheDay);
    expect(upcoming).toHaveLength(1);
    expect(upcoming[0].daysUntil).toBe(0);
  });

  it('sorts multiple active occasions by weight, highest first', () => {
    const soon: OccasionCalendarEntry = { slug: 'a', name: 'A', month: 6, day: 1, isMovable: false, occasionSlug: 'x', leadDays: 10 };
    const today = new Date(2025, 5, 1); // exactly on "soon"'s day -> weight 1
    const farther: OccasionCalendarEntry = { slug: 'b', name: 'B', month: 6, day: 8, isMovable: false, occasionSlug: 'y', leadDays: 10 };
    // "farther" is 7 days out from today -> lower weight than "soon" (0 days out)

    const upcoming = getUpcomingOccasions([farther, soon], today);
    expect(upcoming[0].occasionSlug).toBe('x');
    expect(upcoming[1].occasionSlug).toBe('y');
  });
});
