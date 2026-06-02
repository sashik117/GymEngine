import { BadRequestException } from '@nestjs/common';
import { normalizeSyncCode } from './sync-code';

describe('normalizeSyncCode', () => {
  it('normalizes valid sync codes', () => {
    expect(normalizeSyncCode(' gym-2026-a ')).toBe('GYM-2026-A');
  });

  it('rejects invalid sync codes', () => {
    expect(() => normalizeSyncCode('short')).toThrow(BadRequestException);
  });
});

