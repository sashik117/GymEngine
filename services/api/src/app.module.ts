import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { MailService } from './auth/mail.service';
import { SyncController } from './sync/sync.controller';
import { SyncService } from './sync/sync.service';

@Module({
  controllers: [AppController, AuthController, SyncController],
  providers: [AuthService, MailService, SyncService],
})
export class AppModule {}
