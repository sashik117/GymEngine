import { SyncSnapshotMetrics } from './sync-snapshot.metrics';

describe('SyncSnapshotMetrics', () => {
  it('counts snapshot entities without mutating payloads', () => {
    const metrics = new SyncSnapshotMetrics();
    const snapshot = {
      profile: {},
      exercises: [
        { id: 'bench', name: 'Bench Press', primaryMuscle: 'Chest' },
      ],
      trainingDays: [
        {
          id: 'day-1',
          dayOfWeek: 1,
          dayNumber: 1,
          customName: 'Push',
          restSeconds: 90,
          setTargetSeconds: 0,
          createdAt: '2026-06-02T00:00:00.000Z',
          updatedAt: '2026-06-02T00:00:00.000Z',
        },
      ],
      plannedExercises: [
        {
          id: 'plan-1',
          dayId: 'day-1',
          exerciseId: 'bench',
          sortOrder: 0,
          targetSets: 3,
          targetReps: 10,
        },
      ],
      sessions: [
        {
          id: 'session-1',
          startedAt: '2026-06-02T10:00:00.000Z',
        },
      ],
      sets: [
        {
          id: 'set-1',
          sessionId: 'session-1',
          exerciseId: 'bench',
          exerciseName: 'Bench Press',
          weightKg: 50,
          reps: 10,
          loggedAt: '2026-06-02T10:05:00.000Z',
        },
      ],
      progressPhotos: [
        {
          id: 'photo-1',
          imageDataUrl: 'data:image/png;base64,AA==',
          capturedAt: '2026-06-02T11:00:00.000Z',
          createdAt: '2026-06-02T11:00:00.000Z',
        },
      ],
    };

    expect(metrics.count(snapshot)).toEqual({
      exercises: 1,
      trainingDays: 1,
      plannedExercises: 1,
      sessions: 1,
      sets: 1,
      progressPhotos: 1,
    });
  });
});
