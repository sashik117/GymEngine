export type SyncProfile = {
  displayName?: string;
  bodyWeightKg?: number | null;
  userId?: string;
  email?: string;
  authBaseUrl?: string;
  syncCode?: string;
  syncBaseUrl?: string;
};

export type SyncExercise = {
  id: string;
  name: string;
  primaryMuscle: string;
  createdAt?: string;
  syncStatus?: string;
};

export type SyncTrainingDay = {
  id: string;
  dayOfWeek: number;
  dayNumber: number;
  customName: string;
  restSeconds: number;
  setTargetSeconds: number;
  createdAt: string;
  updatedAt: string;
  syncStatus?: string;
};

export type SyncPlannedExercise = {
  id: string;
  dayId: string;
  exerciseId: string;
  sortOrder: number;
  targetSets: number;
  targetReps: number;
};

export type SyncSession = {
  id: string;
  startedAt: string;
  finishedAt?: string | null;
  templateName?: string | null;
  templateDayNumber?: number | null;
  syncStatus?: string;
};

export type SyncSet = {
  id: string;
  sessionId: string;
  exerciseId?: string | null;
  exerciseName: string;
  weightKg: number;
  reps: number;
  loggedAt: string;
  syncStatus?: string;
};

export type SyncSnapshot = {
  schemaVersion?: number;
  exportedAt?: string;
  userId?: string;
  syncCode?: string;
  serverSavedAt?: string;
  serverVersion?: number;
  profile: SyncProfile;
  exercises: SyncExercise[];
  trainingDays: SyncTrainingDay[];
  plannedExercises: SyncPlannedExercise[];
  sessions: SyncSession[];
  sets: SyncSet[];
};
