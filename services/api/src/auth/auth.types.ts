export type AuthCredentials = {
  email?: string;
  password?: string;
};

export type AuthCodeRequest = {
  email?: string;
};

export type AuthCodeVerification = {
  email?: string;
  code?: string;
};

export type PasswordResetConfirmation = {
  email?: string;
  code?: string;
  password?: string;
};

export type StoredUser = {
  id: string;
  email: string;
  passwordHash: string;
  emailVerifiedAt?: string;
  createdAt: string;
  updatedAt: string;
};

export type PendingRegistration = {
  email: string;
  passwordHash: string;
  codeHash: string;
  expiresAt: string;
  createdAt: string;
  updatedAt: string;
  attempts: number;
};

export type PasswordResetChallenge = {
  email: string;
  codeHash: string;
  expiresAt: string;
  createdAt: string;
  updatedAt: string;
  attempts: number;
};

export type AuthStore = {
  users: StoredUser[];
  pendingRegistrations: PendingRegistration[];
  passwordResets: PasswordResetChallenge[];
};

export type AuthMessage = {
  message: string;
  expiresInSeconds?: number;
};

export type AuthSession = {
  token: string;
  user: {
    id: string;
    email: string;
  };
};
