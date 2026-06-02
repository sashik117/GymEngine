import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';

@Injectable()
export class AuthCodeService {
  private readonly tokenSecret =
    process.env.AUTH_TOKEN_SECRET ?? 'gymengine-dev-secret-change-me';
  private readonly codeTtlMs = Number(process.env.AUTH_CODE_TTL_MS ?? 600000);
  private readonly maxCodeAttempts = Number(
    process.env.AUTH_CODE_MAX_ATTEMPTS ?? 5,
  );

  createCode() {
    return randomInt(0, 1000000).toString().padStart(6, '0');
  }

  expiresAt() {
    return new Date(Date.now() + this.codeTtlMs).toISOString();
  }

  expiresInSeconds() {
    return Math.round(this.codeTtlMs / 1000);
  }

  normalizeCode(value?: string) {
    const code = (value ?? '').replace(/\D/g, '');
    if (!/^\d{6}$/.test(code)) {
      throw new BadRequestException('Six digit code is required');
    }
    return code;
  }

  assertChallengeIsUsable(expiresAt: string, attempts: number) {
    if (Date.parse(expiresAt) <= Date.now()) {
      throw new UnauthorizedException('Verification code expired');
    }
    if (attempts >= this.maxCodeAttempts) {
      throw new UnauthorizedException('Too many code attempts');
    }
  }

  hashCode(email: string, code: string) {
    return createHmac('sha256', this.tokenSecret)
      .update(`${email}:${code}`)
      .digest('base64url');
  }

  verifyCode(email: string, code: string, expectedHash: string) {
    const actualHash = this.hashCode(email, code);
    return (
      actualHash.length === expectedHash.length &&
      timingSafeEqual(Buffer.from(actualHash), Buffer.from(expectedHash))
    );
  }
}

