import { UnauthorizedException } from '@nestjs/common';
import { AuthTokenService } from './auth-token.service';

describe('AuthTokenService', () => {
  it('signs and verifies auth tokens', () => {
    process.env.AUTH_TOKEN_SECRET = 'test-secret';
    const service = new AuthTokenService();

    const token = service.sign({ sub: 'user-1', email: 'test@example.com' });
    const payload = service.verify(token);

    expect(payload.sub).toBe('user-1');
    expect(payload.email).toBe('test@example.com');
    expect(payload.exp).toBeGreaterThan(Math.floor(Date.now() / 1000));
  });

  it('rejects malformed bearer headers', () => {
    const service = new AuthTokenService();

    expect(() => service.extractBearerToken('Token abc')).toThrow(
      UnauthorizedException,
    );
  });
});

