export type TrainingPlanExercise = {
  id: string;
  dayId: string;
  exerciseId: string;
  sortOrder: number;
  targetSets: number;
  targetReps: number;
};

export type WorkoutPlan = {
  id: string;
  dayNumber: number;
  name: string;
  restSeconds: number;
  exercises: TrainingPlanExercise[];
};

