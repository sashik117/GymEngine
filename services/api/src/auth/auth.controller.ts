import { Body, Controller, Get, Headers, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import {
  AuthCodeRequestDto,
  AuthCodeVerificationDto,
  AuthCredentialsDto,
  PasswordResetConfirmationDto,
} from './auth.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() credentials: AuthCredentialsDto) {
    return this.authService.register(credentials);
  }

  @Post('register/verify')
  verifyRegistrationCode(@Body() payload: AuthCodeVerificationDto) {
    return this.authService.verifyRegistrationCode(payload);
  }

  @Post('login')
  login(@Body() credentials: AuthCredentialsDto) {
    return this.authService.login(credentials);
  }

  @Post('password-reset')
  requestPasswordReset(@Body() payload: AuthCodeRequestDto) {
    return this.authService.requestPasswordReset(payload);
  }

  @Post('password-reset/confirm')
  confirmPasswordReset(@Body() payload: PasswordResetConfirmationDto) {
    return this.authService.confirmPasswordReset(payload);
  }

  @Get('me')
  me(@Headers('authorization') authorization?: string) {
    return this.authService.requireUser(authorization);
  }
}
