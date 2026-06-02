import { Injectable } from '@nestjs/common';
import { normalizeSyncCode } from './sync-code';
import { SyncSnapshotRepository } from './sync-snapshot.repository';

@Injectable()
export class SyncQueryService {
  constructor(private readonly repository: SyncSnapshotRepository) {}

  restoreForUser(userId: string) {
    return this.repository.readByUserId(userId);
  }

  restore(rawSyncCode: string) {
    const syncCode = normalizeSyncCode(rawSyncCode);
    return this.repository.readBySyncCode(syncCode);
  }
}

