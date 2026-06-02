import { BadRequestException } from '@nestjs/common';

export function normalizeEmail(value?: string) {
  const email = value?.trim().toLowerCase() ?? '';
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new BadRequestException('Valid email is required');
  }
  return email;
}

export function normalizePassword(value?: string) {
  const password = value ?? '';
  if (password.length < 6) {
    throw new BadRequestException('Password must contain at least 6 chars');
  }
  return password;
}

