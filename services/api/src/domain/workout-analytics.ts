import { Exercise } from './exercise';
import { TrainingPlanExercise, WorkoutPlan } from './workout-plan';
import { Workout, WorkoutSet } from './workout';

export type SnapshotCounts = {
  exercises: number;
  trainingDays: number;
  plannedExercises: number;
  sessions: number;
  sets: number;
  progressPhotos: number;
};

export type WorkoutAnalyticsInput = {
  exercises: Exercise[];
  trainingDays: WorkoutPlan[];
  plannedExercises: TrainingPlanExercise[];
  sessions: Workout[];
  sets: WorkoutSet[];
  progressPhotos?: unknown[];
};

export class WorkoutAnalytics {
  static countSnapshot(input: WorkoutAnalyticsInput): SnapshotCounts {
    return {
      exercises: input.exercises.length,
      trainingDays: input.trainingDays.length,
      plannedExercises: input.plannedExercises.length,
      sessions: input.sessions.length,
      sets: input.sets.length,
      progressPhotos: input.progressPhotos?.length ?? 0,
    };
  }
}
