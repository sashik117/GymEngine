import { PasswordHasher } from './password-hasher.service';

describe('PasswordHasher', () => {
  it('hashes and verifies a password', () => {
    const hasher = new PasswordHasher();
    const hash = hasher.hash('Gym12345');

    expect(hash).toMatch(/^pbkdf2_sha256\$/);
    expect(hasher.verify('Gym12345', hash)).toBe(true);
    expect(hasher.verify('Wrong123', hash)).toBe(false);
  });
});

