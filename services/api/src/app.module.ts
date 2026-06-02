import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AuthCodeService } from './auth/auth-code.service';
import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { AuthStoreRepository } from './auth/auth-store.repository';
import { AuthTokenService } from './auth/auth-token.service';
import { MailService } from './auth/mail.service';
import { PasswordHasher } from './auth/password-hasher.service';
import { SyncController } from './sync/sync.controller';
import { SyncCommandService } from './sync/sync-command.service';
import { SyncQueryService } from './sync/sync-query.service';
import { SyncService } from './sync/sync.service';
import { SyncSnapshotMetrics } from './sync/sync-snapshot.metrics';
import { SyncSnapshotRepository } from './sync/sync-snapshot.repository';
import { SyncSnapshotValidator } from './sync/sync-snapshot.validator';

@Module({
  controllers: [AppController, AuthController, SyncController],
  providers: [
    AuthService,
    MailService,
    AuthStoreRepository,
    PasswordHasher,
    AuthTokenService,
    AuthCodeService,
    SyncService,
    SyncQueryService,
    SyncCommandService,
    SyncSnapshotRepository,
    SyncSnapshotValidator,
    SyncSnapshotMetrics,
  ],
})
export class AppModule {}
