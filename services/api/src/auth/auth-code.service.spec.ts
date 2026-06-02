import { UnauthorizedException } from '@nestjs/common';
import { AuthCodeService } from './auth-code.service';

describe('AuthCodeService', () => {
  it('normalizes, hashes, and verifies six digit codes', () => {
    process.env.AUTH_TOKEN_SECRET = 'code-secret';
    const service = new AuthCodeService();
    const email = 'test@example.com';
    const code = service.normalizeCode('123-456');
    const hash = service.hashCode(email, code);

    expect(code).toBe('123456');
    expect(service.verifyCode(email, code, hash)).toBe(true);
    expect(service.verifyCode(email, '000000', hash)).toBe(false);
  });

  it('rejects expired challenges', () => {
    const service = new AuthCodeService();

    expect(() =>
      service.assertChallengeIsUsable('2000-01-01T00:00:00.000Z', 0),
    ).toThrow(UnauthorizedException);
  });
});

