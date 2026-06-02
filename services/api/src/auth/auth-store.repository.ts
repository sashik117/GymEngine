import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { AuthStore } from './auth.types';

@Injectable()
export class AuthStoreRepository {
  private readonly usersPath =
    process.env.USERS_DATA_PATH ??
    join(process.cwd(), '.data', 'auth', 'users.json');

  async read(): Promise<AuthStore> {
    try {
      const raw = await readFile(this.usersPath, 'utf8');
      const parsed = JSON.parse(raw);
      return {
        users: Array.isArray(parsed.users) ? parsed.users : [],
        pendingRegistrations: Array.isArray(parsed.pendingRegistrations)
          ? parsed.pendingRegistrations
          : [],
        passwordResets: Array.isArray(parsed.passwordResets)
          ? parsed.passwordResets
          : [],
      };
    } catch {
      return {
        users: [],
        pendingRegistrations: [],
        passwordResets: [],
      };
    }
  }

  async write(store: AuthStore) {
    await mkdir(dirname(this.usersPath), { recursive: true });
    const tmpPath = `${this.usersPath}.${randomUUID()}.tmp`;
    await writeFile(
      tmpPath,
      `${JSON.stringify(
        {
          users: store.users,
          pendingRegistrations: store.pendingRegistrations,
          passwordResets: store.passwordResets,
        },
        null,
        2,
      )}\n`,
      'utf8',
    );
    await rename(tmpPath, this.usersPath);
  }
}

