import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import {
  createHmac,
  pbkdf2Sync,
  randomBytes,
  randomInt,
  randomUUID,
  timingSafeEqual,
} from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import {
  AuthCodeRequest,
  AuthCodeVerification,
  AuthCredentials,
  AuthMessage,
  AuthSession,
  AuthStore,
  PasswordResetConfirmation,
  StoredUser,
} from './auth.types';
import { MailService } from './mail.service';

@Injectable()
export class AuthService {
  private readonly usersPath =
    process.env.USERS_DATA_PATH ??
    join(process.cwd(), '.data', 'auth', 'users.json');
  private readonly tokenSecret =
    process.env.AUTH_TOKEN_SECRET ?? 'gymengine-dev-secret-change-me';
  private readonly codeTtlMs = Number(process.env.AUTH_CODE_TTL_MS ?? 600000);
  private readonly maxCodeAttempts = Number(
    process.env.AUTH_CODE_MAX_ATTEMPTS ?? 5,
  );

  constructor(private readonly mailService: MailService) {}

  async register(credentials: AuthCredentials): Promise<AuthMessage> {
    const email = this.normalizeEmail(credentials.email);
    const password = this.normalizePassword(credentials.password);
    const store = await this.readStore();

    if (store.users.some((user) => user.email === email)) {
      throw new BadRequestException('Email already registered');
    }

    const now = new Date().toISOString();
    const code = this.createCode();
    const pendingRegistration = {
      email,
      passwordHash: this.hashPassword(password),
      codeHash: this.hashCode(email, code),
      expiresAt: this.expiresAt(),
      createdAt: now,
      updatedAt: now,
      attempts: 0,
    };

    store.pendingRegistrations = store.pendingRegistrations.filter(
      (item) => item.email !== email,
    );
    store.pendingRegistrations.push(pendingRegistration);
    await this.writeStore(store);
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
      expiresInSeconds: Math.round(this.codeTtlMs / 1000),
    };
  }

  async verifyRegistrationCode(
    payload: AuthCodeVerification,
  ): Promise<AuthSession> {
    const email = this.normalizeEmail(payload.email);
    const code = this.normalizeCode(payload.code);
    const store = await this.readStore();
    const pending = store.pendingRegistrations.find(
      (item) => item.email === email,
    );

    if (!pending) {
      throw new BadRequestException('Verification code was not requested');
    }
    if (store.users.some((user) => user.email === email)) {
      throw new BadRequestException('Email already registered');
    }
    this.assertChallengeIsUsable(pending.expiresAt, pending.attempts);

    if (!this.verifyCode(email, code, pending.codeHash)) {
      pending.attempts += 1;
      pending.updatedAt = new Date().toISOString();
      await this.writeStore(store);
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
    await this.writeStore(store);

    return this.sessionFor(user);
  }

  async requestPasswordReset(payload: AuthCodeRequest): Promise<AuthMessage> {
    const email = this.normalizeEmail(payload.email);
    const store = await this.readStore();
    const user = store.users.find((item) => item.email === email);

    if (!user) {
      return {
        message: 'reset_sent',
        expiresInSeconds: Math.round(this.codeTtlMs / 1000),
      };
    }

    const now = new Date().toISOString();
    const code = this.createCode();
    store.passwordResets = store.passwordResets.filter(
      (item) => item.email !== email,
    );
    store.passwordResets.push({
      email,
      codeHash: this.hashCode(email, code),
      expiresAt: this.expiresAt(),
      createdAt: now,
      updatedAt: now,
      attempts: 0,
    });
    await this.writeStore(store);
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
      expiresInSeconds: Math.round(this.codeTtlMs / 1000),
    };
  }

  async confirmPasswordReset(
    payload: PasswordResetConfirmation,
  ): Promise<AuthSession> {
    const email = this.normalizeEmail(payload.email);
    const code = this.normalizeCode(payload.code);
    const password = this.normalizePassword(payload.password);
    const store = await this.readStore();
    const user = store.users.find((item) => item.email === email);
    const challenge = store.passwordResets.find((item) => item.email === email);

    if (!user || !challenge) {
      throw new BadRequestException('Password reset code was not requested');
    }
    this.assertChallengeIsUsable(challenge.expiresAt, challenge.attempts);

    if (!this.verifyCode(email, code, challenge.codeHash)) {
      challenge.attempts += 1;
      challenge.updatedAt = new Date().toISOString();
      await this.writeStore(store);
      throw new UnauthorizedException('Invalid password reset code');
    }

    user.passwordHash = this.hashPassword(password);
    user.updatedAt = new Date().toISOString();
    store.passwordResets = store.passwordResets.filter(
      (item) => item.email !== email,
    );
    await this.writeStore(store);

    return this.sessionFor(user);
  }

  async login(credentials: AuthCredentials): Promise<AuthSession> {
    const email = this.normalizeEmail(credentials.email);
    const password = this.normalizePassword(credentials.password);
    const store = await this.readStore();
    const user = store.users.find((item) => item.email === email);

    if (!user || !this.verifyPassword(password, user.passwordHash)) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.sessionFor(user);
  }

  requireUser(authorization?: string) {
    const token = this.extractBearerToken(authorization);
    const payload = this.verifyToken(token);

    return {
      id: payload.sub,
      email: payload.email,
    };
  }

  private sessionFor(user: StoredUser): AuthSession {
    return {
      token: this.signToken({ sub: user.id, email: user.email }),
      user: {
        id: user.id,
        email: user.email,
      },
    };
  }

  private normalizeEmail(value?: string) {
    const email = value?.trim().toLowerCase() ?? '';
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new BadRequestException('Valid email is required');
    }
    return email;
  }

  private normalizePassword(value?: string) {
    const password = value ?? '';
    if (password.length < 6) {
      throw new BadRequestException('Password must contain at least 6 chars');
    }
    return password;
  }

  private normalizeCode(value?: string) {
    const code = (value ?? '').replace(/\D/g, '');
    if (!/^\d{6}$/.test(code)) {
      throw new BadRequestException('Six digit code is required');
    }
    return code;
  }

  private async readStore(): Promise<AuthStore> {
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

  private async writeStore(store: AuthStore) {
    await mkdir(dirname(this.usersPath), { recursive: true });
    const tmpPath = `${this.usersPath}.tmp`;
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

  private createCode() {
    return randomInt(0, 1000000).toString().padStart(6, '0');
  }

  private expiresAt() {
    return new Date(Date.now() + this.codeTtlMs).toISOString();
  }

  private assertChallengeIsUsable(expiresAt: string, attempts: number) {
    if (Date.parse(expiresAt) <= Date.now()) {
      throw new UnauthorizedException('Verification code expired');
    }
    if (attempts >= this.maxCodeAttempts) {
      throw new UnauthorizedException('Too many code attempts');
    }
  }

  private hashCode(email: string, code: string) {
    return createHmac('sha256', this.tokenSecret)
      .update(`${email}:${code}`)
      .digest('base64url');
  }

  private verifyCode(email: string, code: string, expectedHash: string) {
    const actualHash = this.hashCode(email, code);
    return (
      actualHash.length === expectedHash.length &&
      timingSafeEqual(Buffer.from(actualHash), Buffer.from(expectedHash))
    );
  }

  private hashPassword(password: string) {
    const salt = randomBytes(16).toString('base64url');
    const hash = pbkdf2Sync(password, salt, 210000, 32, 'sha256').toString(
      'base64url',
    );
    return `pbkdf2_sha256$${salt}$${hash}`;
  }

  private verifyPassword(password: string, storedHash: string) {
    const [scheme, salt, expectedHash] = storedHash.split('$');
    if (scheme !== 'pbkdf2_sha256' || !salt || !expectedHash) {
      return false;
    }

    const actual = pbkdf2Sync(password, salt, 210000, 32, 'sha256').toString(
      'base64url',
    );
    const expectedBuffer = Buffer.from(expectedHash);
    const actualBuffer = Buffer.from(actual);
    return (
      expectedBuffer.length === actualBuffer.length &&
      timingSafeEqual(expectedBuffer, actualBuffer)
    );
  }

  private signToken(payload: { sub: string; email: string }) {
    const body = Buffer.from(
      JSON.stringify({
        ...payload,
        exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30,
      }),
    ).toString('base64url');
    const signature = createHmac('sha256', this.tokenSecret)
      .update(body)
      .digest('base64url');

    return `${body}.${signature}`;
  }

  private verifyToken(token: string) {
    const [body, signature] = token.split('.');
    if (!body || !signature) {
      throw new UnauthorizedException('Invalid token');
    }

    const expectedSignature = createHmac('sha256', this.tokenSecret)
      .update(body)
      .digest('base64url');
    if (
      expectedSignature.length !== signature.length ||
      !timingSafeEqual(Buffer.from(expectedSignature), Buffer.from(signature))
    ) {
      throw new UnauthorizedException('Invalid token');
    }

    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (
      typeof payload.sub !== 'string' ||
      typeof payload.email !== 'string' ||
      typeof payload.exp !== 'number' ||
      payload.exp < Math.floor(Date.now() / 1000)
    ) {
      throw new UnauthorizedException('Expired token');
    }

    return payload as { sub: string; email: string; exp: number };
  }

  private extractBearerToken(authorization?: string) {
    const [scheme, token] = authorization?.split(' ') ?? [];
    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException('Authorization bearer token required');
    }
    return token;
  }
}
