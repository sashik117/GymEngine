import { Body, Controller, Get, Headers, Param, Put } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { SyncCommandService } from './sync-command.service';
import { SyncQueryService } from './sync-query.service';
import { SyncSnapshot } from './sync.types';

@Controller('sync')
export class SyncController {
  constructor(
    private readonly syncQueryService: SyncQueryService,
    private readonly syncCommandService: SyncCommandService,
    private readonly authService: AuthService,
  ) {}

  @Get('me')
  restoreMine(@Headers('authorization') authorization?: string) {
    const user = this.authService.requireUser(authorization);
    return this.syncQueryService.restoreForUser(user.id);
  }

  @Put('me')
  saveMine(
    @Headers('authorization') authorization: string | undefined,
    @Body() snapshot: SyncSnapshot,
  ) {
    const user = this.authService.requireUser(authorization);
    return this.syncCommandService.saveForUser(user.id, snapshot);
  }

  @Get(':syncCode')
  restore(@Param('syncCode') syncCode: string) {
    return this.syncQueryService.restore(syncCode);
  }

  @Put(':syncCode')
  save(@Param('syncCode') syncCode: string, @Body() snapshot: SyncSnapshot) {
    return this.syncCommandService.save(syncCode, snapshot);
  }
}
