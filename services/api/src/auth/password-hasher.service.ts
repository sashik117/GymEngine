import { Injectable } from '@nestjs/common';
import { pbkdf2Sync, randomBytes, timingSafeEqual } from 'node:crypto';

@Injectable()
export class PasswordHasher {
  hash(password: string) {
    const salt = randomBytes(16).toString('base64url');
    const hash = pbkdf2Sync(password, salt, 210000, 32, 'sha256').toString(
      'base64url',
    );
    return `pbkdf2_sha256$${salt}$${hash}`;
  }

  verify(password: string, storedHash: string) {
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
}

