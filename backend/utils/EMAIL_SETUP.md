# Email Service Setup

This document explains how to configure the email service for email verification.

## Environment Variables

Add the following environment variables to your `.env` file:

```env
# Email Service Configuration
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
EMAIL_FROM_NAME=GrabGo

# Frontend URL (for email verification links)
FRONTEND_URL=http://localhost:3000
```

## Gmail Setup

If you're using Gmail:

1. **Enable 2-Step Verification** on your Google account
2. **Generate an App Password**:
   - Go to [Google Account Settings](https://myaccount.google.com/)
   - Navigate to Security → 2-Step Verification → App passwords
   - Generate a new app password for "Mail"
   - Use this app password as `EMAIL_PASS` in your `.env` file

## Other Email Providers

### Outlook/Hotmail
```env
EMAIL_HOST=smtp-mail.outlook.com
EMAIL_PORT=587
EMAIL_SECURE=false
```

### SendGrid
```env
EMAIL_HOST=smtp.sendgrid.net
EMAIL_PORT=587
EMAIL_USER=apikey
EMAIL_PASS=your-sendgrid-api-key
```

### Mailgun
```env
EMAIL_HOST=smtp.mailgun.org
EMAIL_PORT=587
EMAIL_USER=your-mailgun-username
EMAIL_PASS=your-mailgun-password
```

### AWS SES
```env
EMAIL_HOST=email-smtp.us-east-1.amazonaws.com
EMAIL_PORT=587
EMAIL_USER=your-aws-access-key
EMAIL_PASS=your-aws-secret-key
```

## Testing

The email service will work even if not configured (it will log a warning). For production, make sure to configure the email service properly.

## Email Verification Endpoints

1. **POST /api/users/verify-email** - Verify email with OTP code
   - Body: `{ "email": "user@example.com", "otp": "123456" }`
   - OTP codes are 6 digits and expire after 10 minutes

2. **POST /api/users/resend-verification** - Resend verification email with OTP (public)
   - Body: `{ "email": "user@example.com" }`
   - Generates a new OTP code and sends it via email

3. **POST /api/users/send-verification** - Send verification email (authenticated)
   - Requires: Authentication token
   - Uses the logged-in user's email
   - Generates a new OTP code and sends it via email

## Notes

- OTP codes are 6 digits and expire after 10 minutes
- Email sending is non-blocking (won't delay registration)
- If email service is not configured, registration will still succeed but no email will be sent
- OTP codes are sent in the email body (not as links)

