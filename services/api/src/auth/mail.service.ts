import { Injectable, Logger } from '@nestjs/common';
import { mkdir, appendFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import * as nodemailer from 'nodemailer';

type MailPayload = {
  to: string;
  subject: string;
  text: string;
};

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly outboxPath =
    process.env.MAIL_OUTBOX_PATH ??
    join(process.cwd(), '.data', 'mail', 'outbox.jsonl');

  async send(payload: MailPayload) {
    if (process.env.SMTP_HOST) {
      await this.sendWithSmtp(payload);
      return;
    }

    await this.writeDevOutbox(payload);
  }

  private async sendWithSmtp(payload: MailPayload) {
    const port = Number(process.env.SMTP_PORT ?? 587);
    const secure = (process.env.SMTP_SECURE ?? '').toLowerCase() === 'true';
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port,
      secure,
      auth: user && pass ? { user, pass } : undefined,
    });

    await transporter.sendMail({
      from: process.env.SMTP_FROM ?? user ?? 'GymEngine <no-reply@gymengine.local>',
      to: payload.to,
      subject: payload.subject,
      text: payload.text,
    });
  }

  private async writeDevOutbox(payload: MailPayload) {
    await mkdir(dirname(this.outboxPath), { recursive: true });
    const entry = {
      ...payload,
      createdAt: new Date().toISOString(),
      mode: 'dev-outbox',
    };
    await appendFile(this.outboxPath, `${JSON.stringify(entry)}\n`, 'utf8');
    this.logger.warn(
      `SMTP is not configured. Verification email for ${payload.to} was written to ${this.outboxPath}`,
    );
  }
}
