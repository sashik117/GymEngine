import { Injectable, NotFoundException } from '@nestjs/common';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { SyncSnapshot } from './sync.types';

@Injectable()
export class SyncSnapshotRepository {
  private readonly dataDir =
    process.env.SYNC_DATA_DIR ?? join(process.cwd(), '.data', 'sync');
  private readonly userDataDir =
    process.env.USER_SYNC_DATA_DIR ?? join(process.cwd(), '.data', 'user-sync');

  async readByUserId(userId: string) {
    try {
      const raw = await readFile(this.userSnapshotPath(userId), 'utf8');
      return JSON.parse(raw) as SyncSnapshot;
    } catch {
      throw new NotFoundException({
        message: 'User sync snapshot not found',
        userId,
      });
    }
  }

  async writeByUserId(userId: string, snapshot: SyncSnapshot) {
    await mkdir(this.userDataDir, { recursive: true });
    await this.writeJsonAtomic(this.userSnapshotPath(userId), snapshot);
  }

  async readBySyncCode(syncCode: string) {
    try {
      const raw = await readFile(this.snapshotPath(syncCode), 'utf8');
      return JSON.parse(raw) as SyncSnapshot;
    } catch {
      throw new NotFoundException({
        message: 'Sync snapshot not found',
        syncCode,
      });
    }
  }

  async writeBySyncCode(syncCode: string, snapshot: SyncSnapshot) {
    await mkdir(this.dataDir, { recursive: true });
    await this.writeJsonAtomic(this.snapshotPath(syncCode), snapshot);
  }

  private async writeJsonAtomic(path: string, payload: unknown) {
    const tmpPath = `${path}.tmp`;
    await writeFile(tmpPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
    await rename(tmpPath, path);
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

