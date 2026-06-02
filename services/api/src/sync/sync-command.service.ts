import { Injectable } from '@nestjs/common';
import { normalizeSyncCode } from './sync-code';
import { SyncSnapshotMetrics } from './sync-snapshot.metrics';
import { SyncSnapshotRepository } from './sync-snapshot.repository';
import { SyncSnapshotValidator } from './sync-snapshot.validator';
import { SyncSnapshot } from './sync.types';

@Injectable()
export class SyncCommandService {
  constructor(
    private readonly repository: SyncSnapshotRepository,
    private readonly validator: SyncSnapshotValidator,
    private readonly metrics: SyncSnapshotMetrics,
  ) {}

  async saveForUser(userId: string, snapshot: SyncSnapshot) {
    this.validator.assertValid(snapshot);

    const savedAt = new Date().toISOString();
    const payload = {
      ...snapshot,
      userId,
      serverSavedAt: savedAt,
      serverVersion: 2,
    };

    await this.repository.writeByUserId(userId, payload);

    return {
      status: 'ok',
      userId,
      savedAt,
      counts: this.metrics.count(payload),
    };
  }

  async save(rawSyncCode: string, snapshot: SyncSnapshot) {
    const syncCode = normalizeSyncCode(rawSyncCode);
    this.validator.assertValid(snapshot);

    const savedAt = new Date().toISOString();
    const payload = {
      ...snapshot,
      syncCode,
      serverSavedAt: savedAt,
      serverVersion: 1,
    };

    await this.repository.writeBySyncCode(syncCode, payload);

    return {
      status: 'ok',
      syncCode,
      savedAt,
      counts: this.metrics.count(payload),
    };
  }
}

