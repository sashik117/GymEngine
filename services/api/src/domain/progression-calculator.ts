import {
  ProgressionRule,
  defaultStrengthProgressionRule,
} from './progression-rule';

export type ProgressionInput = {
  lastWeightKg: number;
  lastReps: number;
  rule?: ProgressionRule;
};

export type ProgressionResult = {
  nextWeightKg: number;
  reason: 'increase' | 'repeat' | 'deload';
};

export class ProgressionCalculator {
  static calculate(input: ProgressionInput): ProgressionResult {
    const rule = input.rule ?? defaultStrengthProgressionRule;
    const lastWeightKg = Math.max(0, input.lastWeightKg);
    const lastReps = Math.max(0, input.lastReps);

    if (lastReps >= rule.targetReps) {
      return {
        nextWeightKg: ProgressionCalculator.roundWeight(
          lastWeightKg + rule.increaseStepKg,
        ),
        reason: 'increase',
      };
    }

    if (lastReps <= Math.max(1, rule.targetReps - 4)) {
      return {
        nextWeightKg: ProgressionCalculator.roundWeight(
          lastWeightKg * (1 - rule.deloadPercent / 100),
        ),
        reason: 'deload',
      };
    }

    return {
      nextWeightKg: ProgressionCalculator.roundWeight(lastWeightKg),
      reason: 'repeat',
    };
  }

  private static roundWeight(value: number) {
    return Math.round(value * 2) / 2;
  }
}

