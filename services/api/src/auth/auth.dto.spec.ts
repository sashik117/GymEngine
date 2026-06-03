import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { AuthCredentialsDto } from './auth.dto';

describe('Auth DTO validation', () => {
  const pipe = new ValidationPipe({
    transform: true,
    whitelist: true,
    forbidNonWhitelisted: true,
  });

  it('accepts valid auth credentials', async () => {
    await expect(
      pipe.transform(
        { email: 'user@example.com', password: 'Gym12345' },
        { type: 'body', metatype: AuthCredentialsDto },
      ),
    ).resolves.toMatchObject({
      email: 'user@example.com',
      password: 'Gym12345',
    });
  });

  it('rejects unknown auth fields before service logic', async () => {
    await expect(
      pipe.transform(
        { email: 'user@example.com', password: 'Gym12345', role: 'admin' },
        { type: 'body', metatype: AuthCredentialsDto },
      ),
    ).rejects.toThrow(BadRequestException);
  });
});
