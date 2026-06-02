import { Injectable } from '@nestjs/common';
import { WorkoutAnalytics } from '../domain/workout-analytics';
import { SyncSnapshot } from './sync.types';

@Injectable()
export class SyncSnapshotMetrics {
  count(snapshot: SyncSnapshot) {
    return WorkoutAnalytics.countSnapshot({
      exercises: snapshot.exercises ?? [],
      trainingDays: (snapshot.trainingDays ?? []).map((day) => ({
        id: day.id,
        dayNumber: day.dayNumber,
        name: day.customName,
        restSeconds: day.restSeconds,
        exercises: [],
      })),
      plannedExercises: snapshot.plannedExercises ?? [],
      sessions: (snapshot.sessions ?? []).map((session) => ({
        id: session.id,
        startedAt: session.startedAt,
        finishedAt: session.finishedAt,
        templateName: session.templateName,
        templateDayNumber: session.templateDayNumber,
        sets: [],
      })),
      sets: snapshot.sets ?? [],
      progressPhotos: snapshot.progressPhotos ?? [],
    });
  }
}
