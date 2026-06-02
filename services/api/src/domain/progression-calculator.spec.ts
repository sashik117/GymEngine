import { ProgressionCalculator } from './progression-calculator';

describe('ProgressionCalculator', () => {
  it('increases weight when target reps are reached', () => {
    expect(
      ProgressionCalculator.calculate({ lastWeightKg: 50, lastReps: 8 }),
    ).toEqual({ nextWeightKg: 52.5, reason: 'increase' });
  });

  it('repeats weight when performance is near target', () => {
    expect(
      ProgressionCalculator.calculate({ lastWeightKg: 50, lastReps: 6 }),
    ).toEqual({ nextWeightKg: 50, reason: 'repeat' });
  });

  it('deloads when reps fall too far below target', () => {
    expect(
      ProgressionCalculator.calculate({ lastWeightKg: 50, lastReps: 3 }),
    ).toEqual({ nextWeightKg: 45, reason: 'deload' });
  });

  it('supports custom progression rules', () => {
    expect(
      ProgressionCalculator.calculate({
        lastWeightKg: 70,
        lastReps: 10,
        rule: {
          targetReps: 10,
          increaseStepKg: 5,
          deloadPercent: 15,
        },
      }),
    ).toEqual({ nextWeightKg: 75, reason: 'increase' });
  });
});

