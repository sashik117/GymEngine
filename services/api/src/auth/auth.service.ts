import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AuthCodeService } from './auth-code.service';
import { normalizeEmail, normalizePassword } from './auth-input.normalizer';
import { AuthStoreRepository } from './auth-store.repository';
import { AuthTokenService } from './auth-token.service';
import {
  AuthCodeRequest,
  AuthCodeVerification,
  AuthCredentials,
  AuthMessage,
  AuthSession,
  PasswordResetConfirmation,
  StoredUser,
} from './auth.types';
import { MailService } from './mail.service';
import { PasswordHasher } from './password-hasher.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly mailService: MailService,
    private readonly storeRepository: AuthStoreRepository,
    private readonly passwordHasher: PasswordHasher,
    private readonly tokenService: AuthTokenService,
    private readonly codeService: AuthCodeService,
  ) {}

  async register(credentials: AuthCredentials): Promise<AuthMessage> {
    const email = normalizeEmail(credentials.email);
    const password = normalizePassword(credentials.password);
    const store = await this.storeRepository.read();

    if (store.users.some((user) => user.email === email)) {
      throw new BadRequestException('Email already registered');
    }

    const now = new Date().toISOString();
    const code = this.codeService.createCode();
    const pendingRegistration = {
      email,
      passwordHash: this.passwordHasher.hash(password),
      codeHash: this.codeService.hashCode(email, code),
      expiresAt: this.codeService.expiresAt(),
      createdAt: now,
      updatedAt: now,
      attempts: 0,
    };

    store.pendingRegistrations = store.pendingRegistrations.filter(
      (item) => item.email !== email,
    );
    store.pendingRegistrations.push(pendingRegistration);
    await this.storeRepository.write(store);
    await this.mailService.send({
      to: email,
      subject: 'GymEngine: код підтвердження пошти',
      text: [
        'Твій код підтвердження GymEngine:',
        '',
        code,
        '',
        'Код діє 10 хвилин. Якщо це була не ти, просто проігноруй лист.',
      ].join('\n'),
    });

    return {
      message: 'verification_sent',
      expiresInSeconds: this.codeService.expiresInSeconds(),
      devCode: this.shouldExposeDevCode() ? code : undefined,
    };
  }

  async verifyRegistrationCode(
    payload: AuthCodeVerification,
  ): Promise<AuthSession> {
    const email = normalizeEmail(payload.email);
    const code = this.codeService.normalizeCode(payload.code);
    const store = await this.storeRepository.read();
    const pending = store.pendingRegistrations.find(
      (item) => item.email === email,
    );

    if (!pending) {
      throw new BadRequestException('Verification code was not requested');
    }
    if (store.users.some((user) => user.email === email)) {
      throw new BadRequestException('Email already registered');
    }
    this.codeService.assertChallengeIsUsable(
      pending.expiresAt,
      pending.attempts,
    );

    if (!this.codeService.verifyCode(email, code, pending.codeHash)) {
      pending.attempts += 1;
      pending.updatedAt = new Date().toISOString();
      await this.storeRepository.write(store);
      throw new UnauthorizedException('Invalid verification code');
    }

    const now = new Date().toISOString();
    const user: StoredUser = {
      id: randomUUID(),
      email,
      passwordHash: pending.passwordHash,
      emailVerifiedAt: now,
      createdAt: now,
      updatedAt: now,
    };
    store.users.push(user);
    store.pendingRegistrations = store.pendingRegistrations.filter(
      (item) => item.email !== email,
    );
    await this.storeRepository.write(store);

    return this.sessionFor(user);
  }

  async requestPasswordReset(payload: AuthCodeRequest): Promise<AuthMessage> {
    const email = normalizeEmail(payload.email);
    const store = await this.storeRepository.read();
    const user = store.users.find((item) => item.email === email);

    if (!user) {
      return {
        message: 'reset_sent',
        expiresInSeconds: this.codeService.expiresInSeconds(),
      };
    }

    const now = new Date().toISOString();
    const code = this.codeService.createCode();
    store.passwordResets = store.passwordResets.filter(
      (item) => item.email !== email,
    );
    store.passwordResets.push({
      email,
      codeHash: this.codeService.hashCode(email, code),
      expiresAt: this.codeService.expiresAt(),
      createdAt: now,
      updatedAt: now,
      attempts: 0,
    });
    await this.storeRepository.write(store);
    await this.mailService.send({
      to: email,
      subject: 'GymEngine: код скидання паролю',
      text: [
        'Код для скидання паролю GymEngine:',
        '',
        code,
        '',
        'Код діє 10 хвилин. Якщо це була не ти, краще зміни пароль після входу.',
      ].join('\n'),
    });

    return {
      message: 'reset_sent',
      expiresInSeconds: this.codeService.expiresInSeconds(),
      devCode: this.shouldExposeDevCode() ? code : undefined,
    };
  }

  async confirmPasswordReset(
    payload: PasswordResetConfirmation,
  ): Promise<AuthSession> {
    const email = normalizeEmail(payload.email);
    const code = this.codeService.normalizeCode(payload.code);
    const password = normalizePassword(payload.password);
    const store = await this.storeRepository.read();
    const user = store.users.find((item) => item.email === email);
    const challenge = store.passwordResets.find((item) => item.email === email);

    if (!user || !challenge) {
      throw new BadRequestException('Password reset code was not requested');
    }
    this.codeService.assertChallengeIsUsable(
      challenge.expiresAt,
      challenge.attempts,
    );

    if (!this.codeService.verifyCode(email, code, challenge.codeHash)) {
      challenge.attempts += 1;
      challenge.updatedAt = new Date().toISOString();
      await this.storeRepository.write(store);
      throw new UnauthorizedException('Invalid password reset code');
    }

    user.passwordHash = this.passwordHasher.hash(password);
    user.updatedAt = new Date().toISOString();
    store.passwordResets = store.passwordResets.filter(
      (item) => item.email !== email,
    );
    await this.storeRepository.write(store);

    return this.sessionFor(user);
  }

  async login(credentials: AuthCredentials): Promise<AuthSession> {
    const email = normalizeEmail(credentials.email);
    const password = normalizePassword(credentials.password);
    const store = await this.storeRepository.read();
    const user = store.users.find((item) => item.email === email);

    if (!user || !this.passwordHasher.verify(password, user.passwordHash)) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.sessionFor(user);
  }

  requireUser(authorization?: string) {
    const token = this.tokenService.extractBearerToken(authorization);
    const payload = this.tokenService.verify(token);

    return {
      id: payload.sub,
      email: payload.email,
    };
  }

  private sessionFor(user: StoredUser): AuthSession {
    return {
      token: this.tokenService.sign({ sub: user.id, email: user.email }),
      user: {
        id: user.id,
        email: user.email,
      },
    };
  }

  private shouldExposeDevCode() {
    return !process.env.SMTP_HOST;
  }
}
