import { IsEmail, IsString, Length, Matches } from 'class-validator';

export class AuthCredentialsDto {
  @IsEmail()
  email!: string;

  @IsString()
  @Length(6, 128)
  password!: string;
}

export class AuthCodeRequestDto {
  @IsEmail()
  email!: string;
}

export class AuthCodeVerificationDto {
  @IsEmail()
  email!: string;

  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}

export class PasswordResetConfirmationDto extends AuthCodeVerificationDto {
  @IsString()
  @Length(6, 128)
  password!: string;
}
