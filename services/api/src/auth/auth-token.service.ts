import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';

export type AuthTokenPayload = {
  sub: string;
  email: string;
};

@Injectable()
export class AuthTokenService {
  private readonly tokenSecret =
    process.env.AUTH_TOKEN_SECRET ?? 'gymengine-dev-secret-change-me';

  sign(payload: AuthTokenPayload) {
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

  verify(token: string) {
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

    return payload as AuthTokenPayload & { exp: number };
  }

  extractBearerToken(authorization?: string) {
    const [scheme, token] = authorization?.split(' ') ?? [];
    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException('Authorization bearer token required');
    }
    return token;
  }
}

