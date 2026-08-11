import { DEFAULT_WEIGHTS, rankFragrances, scoreFragrance, type ScoringCandidate, type ScoringContext } from '../scoring';

function makeCandidate(overrides: Partial<ScoringCandidate> = {}): ScoringCandidate {
  return {
    fragranceId: 'frag-1',
    name: 'Test Eau',
    brandName: 'Test House',
    imageUrl: null,
    accords: [{ slug: 'citrus', intensity: 80 }],
    seasons: { spring: 50, summer: 50, fall: 50, winter: 50 },
    occasions: [{ slug: 'daily', score: 50 }],
    personalRating: null,
    isSignature: false,
    ...overrides,
  };
}

function makeContext(overrides: Partial<ScoringContext> = {}): ScoringContext {
  return {
    weather: null,
    currentSeason: 'summer',
    activeOccasions: [],
    daysSinceLastWorn: {},
    ...overrides,
  };
}

describe('scoreFragrance — weather fit', () => {
  it('scores a citrus-forward fragrance higher in hot weather than cold weather', () => {
    const citrusHeavy = makeCandidate({ accords: [{ slug: 'citrus', intensity: 100 }] });

    const hot = scoreFragrance(citrusHeavy, makeContext({ weather: { temp_c: 32, feels_like_c: 34, condition: 'clear', humidity: 40, wind_kph: 5, city: null } }));
    const cold = scoreFragrance(citrusHeavy, makeContext({ weather: { temp_c: 0, feels_like_c: -2, condition: 'clear', humidity: 40, wind_kph: 5, city: null } }));

    expect(hot.breakdown.weather).toBeGreaterThan(cold.breakdown.weather);
  });

  it('scores an oriental/amber-heavy fragrance higher in cold weather than hot weather', () => {
    const orientalHeavy = makeCandidate({ accords: [{ slug: 'oriental', intensity: 90 }, { slug: 'amber', intensity: 70 }] });

    const hot = scoreFragrance(orientalHeavy, makeContext({ weather: { temp_c: 32, feels_like_c: 34, condition: 'clear', humidity: 40, wind_kph: 5, city: null } }));
    const cold = scoreFragrance(orientalHeavy, makeContext({ weather: { temp_c: 0, feels_like_c: -2, condition: 'clear', humidity: 40, wind_kph: 5, city: null } }));

    expect(cold.breakdown.weather).toBeGreaterThan(hot.breakdown.weather);
  });

  it('defaults weather fit to neutral (50) when there is no weather signal', () => {
    const result = scoreFragrance(makeCandidate(), makeContext({ weather: null }));
    expect(result.breakdown.weather).toBe(50);
  });

  it('defaults weather fit to neutral (50) when the fragrance has no accord data', () => {
    const result = scoreFragrance(
      makeCandidate({ accords: [] }),
      makeContext({ weather: { temp_c: 30, feels_like_c: 30, condition: 'clear', humidity: 40, wind_kph: 5, city: null } }),
    );
    expect(result.breakdown.weather).toBe(50);
  });
});

describe('scoreFragrance — season fit', () => {
  it('uses the fragrance-season score for the current season', () => {
    const candidate = makeCandidate({ seasons: { spring: 20, summer: 95, fall: 40, winter: 10 } });
    const result = scoreFragrance(candidate, makeContext({ currentSeason: 'summer' }));
    expect(result.breakdown.season).toBe(95);
  });
});

describe('scoreFragrance — occasion fit', () => {
  it('falls back to the "daily" occasion score when nothing is active', () => {
    const candidate = makeCandidate({ occasions: [{ slug: 'daily', score: 72 }, { slug: 'formal', score: 10 }] });
    const result = scoreFragrance(candidate, makeContext({ activeOccasions: [] }));
    expect(result.breakdown.occasion).toBe(72);
  });

  it('falls back to neutral (50) when there is no "daily" tag and nothing is active', () => {
    const candidate = makeCandidate({ occasions: [{ slug: 'formal', score: 10 }] });
    const result = scoreFragrance(candidate, makeContext({ activeOccasions: [] }));
    expect(result.breakdown.occasion).toBe(50);
  });

  it('scores highest-weighted match among active occasions, ignoring occasions the fragrance has no tag for', () => {
    const candidate = makeCandidate({ occasions: [{ slug: 'date_night', score: 80 }] });
    const result = scoreFragrance(
      candidate,
      makeContext({
        activeOccasions: [
          { occasionSlug: 'festive', holidayName: 'New Year', daysUntil: 1, weight: 0.9 },
          { occasionSlug: 'date_night', holidayName: "Valentine's Day", daysUntil: 0, weight: 1 },
        ],
      }),
    );
    expect(result.breakdown.occasion).toBe(80); // date_night match at full weight, festive has no matching tag
  });

  it('a user-requested occasion (weight 1) uses the full tag score', () => {
    const candidate = makeCandidate({ occasions: [{ slug: 'office', score: 65 }] });
    const result = scoreFragrance(candidate, makeContext({ activeOccasions: [{ occasionSlug: 'office', holidayName: '', daysUntil: 0, weight: 1 }] }));
    expect(result.breakdown.occasion).toBe(65);
  });
});

describe('scoreFragrance — personal rating fit', () => {
  it('scales a 0-10 personal rating to 0-100', () => {
    const result = scoreFragrance(makeCandidate({ personalRating: 8 }), makeContext());
    expect(result.breakdown.personalRating).toBe(80);
  });

  it('defaults to neutral (50) when unrated, rather than penalizing it', () => {
    const result = scoreFragrance(makeCandidate({ personalRating: null }), makeContext());
    expect(result.breakdown.personalRating).toBe(50);
  });
});

describe('scoreFragrance — freshness penalty', () => {
  it('is at its maximum for a fragrance worn today', () => {
    const result = scoreFragrance(makeCandidate(), makeContext({ daysSinceLastWorn: { 'frag-1': 0 } }));
    expect(result.breakdown.freshnessPenalty).toBe(100);
  });

  it('decays to zero by the edge of the freshness window', () => {
    const result = scoreFragrance(makeCandidate(), makeContext({ daysSinceLastWorn: { 'frag-1': 5 } }));
    expect(result.breakdown.freshnessPenalty).toBe(0);
  });

  it('is zero when there is no recent-wear record at all', () => {
    const result = scoreFragrance(makeCandidate(), makeContext({ daysSinceLastWorn: {} }));
    expect(result.breakdown.freshnessPenalty).toBe(0);
  });

  it('a fragrance worn today scores lower overall than an identical one not worn recently', () => {
    const wornToday = scoreFragrance(makeCandidate({ fragranceId: 'a' }), makeContext({ daysSinceLastWorn: { a: 0 } }));
    const notWorn = scoreFragrance(makeCandidate({ fragranceId: 'a' }), makeContext({ daysSinceLastWorn: {} }));
    expect(wornToday.score).toBeLessThan(notWorn.score);
  });
});

describe('scoreFragrance — signature bias', () => {
  it('adds a flat bonus for the signature scent', () => {
    const signature = scoreFragrance(makeCandidate({ isSignature: true }), makeContext());
    const regular = scoreFragrance(makeCandidate({ isSignature: false }), makeContext());
    expect(signature.score - regular.score).toBeCloseTo(DEFAULT_WEIGHTS.signatureBias, 5);
  });
});

describe('scoreFragrance — score bounds', () => {
  it('never returns a score outside [0, 100]', () => {
    const worstCase = makeCandidate({
      accords: [{ slug: 'oriental', intensity: 100 }],
      seasons: { spring: 0, summer: 0, fall: 0, winter: 0 },
      occasions: [{ slug: 'daily', score: 0 }],
      personalRating: 0,
    });
    const result = scoreFragrance(
      worstCase,
      makeContext({
        weather: { temp_c: 32, feels_like_c: 34, condition: 'clear', humidity: 10, wind_kph: 0, city: null },
        daysSinceLastWorn: { 'frag-1': 0 },
      }),
    );
    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.score).toBeLessThanOrEqual(100);

    const bestCase = makeCandidate({
      isSignature: true,
      seasons: { spring: 100, summer: 100, fall: 100, winter: 100 },
      occasions: [{ slug: 'daily', score: 100 }],
      personalRating: 10,
    });
    const best = scoreFragrance(bestCase, makeContext());
    expect(best.score).toBeLessThanOrEqual(100);
  });
});

describe('rankFragrances', () => {
  it('sorts candidates by score, best first', () => {
    const low = makeCandidate({ fragranceId: 'low', personalRating: 1, occasions: [{ slug: 'daily', score: 10 }] });
    const high = makeCandidate({ fragranceId: 'high', personalRating: 10, occasions: [{ slug: 'daily', score: 90 }] });
    const mid = makeCandidate({ fragranceId: 'mid', personalRating: 5, occasions: [{ slug: 'daily', score: 50 }] });

    const ranked = rankFragrances([low, high, mid], makeContext());

    expect(ranked.map((r) => r.fragranceId)).toEqual(['high', 'mid', 'low']);
  });
});
