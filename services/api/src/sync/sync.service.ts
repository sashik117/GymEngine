import { Injectable } from '@nestjs/common';
import { SyncCommandService } from './sync-command.service';
import { SyncQueryService } from './sync-query.service';
import { SyncSnapshot } from './sync.types';

@Injectable()
export class SyncService {
  constructor(
    private readonly queryService: SyncQueryService,
    private readonly commandService: SyncCommandService,
  ) {}

  restoreForUser(userId: string) {
    return this.queryService.restoreForUser(userId);
  }

  saveForUser(userId: string, snapshot: SyncSnapshot) {
    return this.commandService.saveForUser(userId, snapshot);
  }

  restore(syncCode: string) {
    return this.queryService.restore(syncCode);
  }

  save(syncCode: string, snapshot: SyncSnapshot) {
    return this.commandService.save(syncCode, snapshot);
  }
}

