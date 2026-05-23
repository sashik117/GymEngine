import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { SyncSnapshot } from './sync.types';

@Injectable()
export class SyncService {
  private readonly dataDir =
    process.env.SYNC_DATA_DIR ?? join(process.cwd(), '.data', 'sync');
  private readonly userDataDir =
    process.env.USER_SYNC_DATA_DIR ?? join(process.cwd(), '.data', 'user-sync');

  async restoreForUser(userId: string) {
    try {
      const raw = await readFile(this.userSnapshotPath(userId), 'utf8');
      return JSON.parse(raw);
    } catch {
      throw new NotFoundException({
        message: 'User sync snapshot not found',
        userId,
      });
    }
  }

  async saveForUser(userId: string, snapshot: SyncSnapshot) {
    this.assertSnapshot(snapshot);

    await mkdir(this.userDataDir, { recursive: true });
    const savedAt = new Date().toISOString();
    const payload = {
      ...snapshot,
      userId,
      serverSavedAt: savedAt,
      serverVersion: 2,
    };
    const path = this.userSnapshotPath(userId);
    const tmpPath = `${path}.tmp`;

    await writeFile(tmpPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
    await rename(tmpPath, path);

    return {
      status: 'ok',
      userId,
      savedAt,
      counts: this.countSnapshot(payload),
    };
  }

  async restore(rawSyncCode: string) {
    const syncCode = this.normalizeSyncCode(rawSyncCode);
    try {
      const raw = await readFile(this.snapshotPath(syncCode), 'utf8');
      return JSON.parse(raw);
    } catch (error) {
      throw new NotFoundException({
        message: 'Sync snapshot not found',
        syncCode,
      });
    }
  }

  async save(rawSyncCode: string, snapshot: SyncSnapshot) {
    const syncCode = this.normalizeSyncCode(rawSyncCode);
    this.assertSnapshot(snapshot);

    await mkdir(this.dataDir, { recursive: true });
    const savedAt = new Date().toISOString();
    const payload = {
      ...snapshot,
      syncCode,
      serverSavedAt: savedAt,
      serverVersion: 1,
    };
    const path = this.snapshotPath(syncCode);
    const tmpPath = `${path}.tmp`;

    await writeFile(tmpPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
    await rename(tmpPath, path);

    return {
      status: 'ok',
      syncCode,
      savedAt,
      counts: this.countSnapshot(payload),
    };
  }

  private normalizeSyncCode(value: string) {
    const normalized = value.trim().toUpperCase();
    if (!/^[A-Z0-9-]{8,40}$/.test(normalized)) {
      throw new BadRequestException('Invalid sync code');
    }
    return normalized;
  }

  private assertSnapshot(snapshot: SyncSnapshot) {
    if (!snapshot || typeof snapshot !== 'object') {
      throw new BadRequestException('Snapshot body is required');
    }
    if (!snapshot.profile || typeof snapshot.profile !== 'object') {
      throw new BadRequestException('Snapshot profile is required');
    }
    if (!Array.isArray(snapshot.exercises)) {
      throw new BadRequestException('Snapshot exercises must be an array');
    }
    if (!Array.isArray(snapshot.trainingDays)) {
      throw new BadRequestException('Snapshot trainingDays must be an array');
    }
    if (!Array.isArray(snapshot.plannedExercises)) {
      throw new BadRequestException('Snapshot plannedExercises must be an array');
    }
    if (!Array.isArray(snapshot.sessions)) {
      throw new BadRequestException('Snapshot sessions must be an array');
    }
    if (!Array.isArray(snapshot.sets)) {
      throw new BadRequestException('Snapshot sets must be an array');
    }
  }

  private countSnapshot(snapshot: SyncSnapshot) {
    return {
      exercises: snapshot.exercises?.length ?? 0,
      trainingDays: snapshot.trainingDays?.length ?? 0,
      plannedExercises: snapshot.plannedExercises?.length ?? 0,
      sessions: snapshot.sessions?.length ?? 0,
      sets: snapshot.sets?.length ?? 0,
    };
  }

  private snapshotPath(syncCode: string) {
    const fileName = `${syncCode.replaceAll('-', '_')}.json`;
    return join(this.dataDir, fileName);
  }

  private userSnapshotPath(userId: string) {
    const safeUserId = userId.replace(/[^a-zA-Z0-9_-]/g, '_');
    return join(this.userDataDir, `${safeUserId}.json`);
  }
}
