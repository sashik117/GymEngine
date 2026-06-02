import { BadRequestException } from '@nestjs/common';
import { SyncSnapshotValidator } from './sync-snapshot.validator';
import { SyncSnapshot } from './sync.types';

describe('SyncSnapshotValidator', () => {
  const validSnapshot: SyncSnapshot = {
    profile: {},
    exercises: [],
    trainingDays: [],
    plannedExercises: [],
    sessions: [],
    sets: [],
  };

  it('accepts a valid snapshot shape', () => {
    expect(() =>
      new SyncSnapshotValidator().assertValid(validSnapshot),
    ).not.toThrow();
  });

  it('accepts progress photos when they are present', () => {
    expect(() =>
      new SyncSnapshotValidator().assertValid({
        ...validSnapshot,
        progressPhotos: [
          {
            id: 'photo-1',
            imageDataUrl: 'data:image/png;base64,AA==',
            capturedAt: '2026-05-16T09:00:00.000Z',
            createdAt: '2026-05-16T09:00:00.000Z',
          },
        ],
      }),
    ).not.toThrow();
  });

  it('rejects malformed collections', () => {
    expect(() =>
      new SyncSnapshotValidator().assertValid({
        ...validSnapshot,
        sets: undefined as unknown as SyncSnapshot['sets'],
      }),
    ).toThrow(BadRequestException);
  });

  it('rejects malformed progress photos', () => {
    expect(() =>
      new SyncSnapshotValidator().assertValid({
        ...validSnapshot,
        progressPhotos: {} as unknown as SyncSnapshot['progressPhotos'],
      }),
    ).toThrow(BadRequestException);
  });
});
