import { Body, Controller, Get, Headers, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import {
  AuthCodeRequest,
  AuthCodeVerification,
  AuthCredentials,
  PasswordResetConfirmation,
} from './auth.types';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() credentials: AuthCredentials) {
    return this.authService.register(credentials);
  }

  @Post('register/verify')
  verifyRegistrationCode(@Body() payload: AuthCodeVerification) {
    return this.authService.verifyRegistrationCode(payload);
  }

  @Post('login')
  login(@Body() credentials: AuthCredentials) {
    return this.authService.login(credentials);
  }

  @Post('password-reset')
  requestPasswordReset(@Body() payload: AuthCodeRequest) {
    return this.authService.requestPasswordReset(payload);
  }

  @Post('password-reset/confirm')
  confirmPasswordReset(@Body() payload: PasswordResetConfirmation) {
    return this.authService.confirmPasswordReset(payload);
  }

  @Get('me')
  me(@Headers('authorization') authorization?: string) {
    return this.authService.requireUser(authorization);
  }
}
