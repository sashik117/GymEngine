import { Body, Controller, Get, Headers, Param, Put } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { SyncService } from './sync.service';
import { SyncSnapshot } from './sync.types';

@Controller('sync')
export class SyncController {
  constructor(
    private readonly syncService: SyncService,
    private readonly authService: AuthService,
  ) {}

  @Get('me')
  restoreMine(@Headers('authorization') authorization?: string) {
    const user = this.authService.requireUser(authorization);
    return this.syncService.restoreForUser(user.id);
  }

  @Put('me')
  saveMine(
    @Headers('authorization') authorization: string | undefined,
    @Body() snapshot: SyncSnapshot,
  ) {
    const user = this.authService.requireUser(authorization);
    return this.syncService.saveForUser(user.id, snapshot);
  }

  @Get(':syncCode')
  restore(@Param('syncCode') syncCode: string) {
    return this.syncService.restore(syncCode);
  }

  @Put(':syncCode')
  save(@Param('syncCode') syncCode: string, @Body() snapshot: SyncSnapshot) {
    return this.syncService.save(syncCode, snapshot);
  }
}
