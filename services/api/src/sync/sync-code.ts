import { BadRequestException } from '@nestjs/common';

export function normalizeSyncCode(value: string) {
  const normalized = value.trim().toUpperCase();
  if (!/^[A-Z0-9-]{8,40}$/.test(normalized)) {
    throw new BadRequestException('Invalid sync code');
  }
  return normalized;
}

