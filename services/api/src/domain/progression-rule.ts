export type ProgressionRule = {
  targetReps: number;
  increaseStepKg: number;
  deloadPercent: number;
};

export const defaultStrengthProgressionRule: ProgressionRule = {
  targetReps: 8,
  increaseStepKg: 2.5,
  deloadPercent: 10,
};

