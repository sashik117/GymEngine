export type WorkoutSet = {
  id: string;
  sessionId: string;
  exerciseId?: string | null;
  exerciseName: string;
  weightKg: number;
  reps: number;
  loggedAt: string;
};

export type Workout = {
  id: string;
  startedAt: string;
  finishedAt?: string | null;
  templateName?: string | null;
  templateDayNumber?: number | null;
  sets: WorkoutSet[];
};

