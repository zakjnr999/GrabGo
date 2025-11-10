# Email Service Setup

This document explains how to configure the email service for email verification.

## Recommended: SendGrid Setup

SendGrid is recommended for production use. It's reliable, has a generous free tier (100 emails/day), and is easy to set up.

### Step 1: Create a SendGrid Account

1. Go to [SendGrid](https://sendgrid.com/) and sign up for a free account
2. Verify your email address
3. Complete the account setup

### Step 2: Create an API Key

1. Log in to your SendGrid dashboard
2. Go to **Settings** → **API Keys**
3. Click **Create API Key**
4. Name it (e.g., "GrabGo Backend")
5. Select **Full Access** or **Restricted Access** (with Mail Send permissions)
6. Click **Create & View**
7. **Copy the API key immediately** (you won't be able to see it again!)

### Step 3: Verify a Sender Identity

1. Go to **Settings** → **Sender Authentication**
2. Click **Verify a Single Sender**
3. Fill in your details:
   - **From Email**: The email address you want to send from (e.g., noreply@grabgo.com)
   - **From Name**: Your name or company name
   - Complete all required fields
4. Click **Create**
5. Check your email and click the verification link

### Step 4: Configure Environment Variables

Add the following to your `.env` file:

```env
# Email Service Configuration (SendGrid)
EMAIL_HOST=smtp.sendgrid.net
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=apikey
EMAIL_PASS=your-sendgrid-api-key-here
EMAIL_FROM_NAME=GrabGo
EMAIL_FROM_EMAIL=noreply@grabgo.com
```

**Important:**
- `EMAIL_USER` should always be `apikey` for SendGrid
- `EMAIL_PASS` should be your SendGrid API key (the one you copied in Step 2)
- `EMAIL_FROM_EMAIL` should be the verified sender email from Step 3
- You can omit `EMAIL_HOST` and `EMAIL_USER` - they will default to SendGrid values

## Alternative: AWS SES Setup

If you prefer to use AWS SES instead of SendGrid:

1. **Create an AWS Account** at [AWS](https://aws.amazon.com/)
2. **Access AWS SES** in the AWS Console
3. **Verify Your Email Address** in SES
4. **Create SMTP Credentials** in SES SMTP settings
5. **Note Your SMTP Endpoint** (e.g., `email-smtp.us-east-1.amazonaws.com`)

```env
# Email Service Configuration (AWS SES)
EMAIL_HOST=email-smtp.us-east-1.amazonaws.com
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=your-aws-access-key-id
EMAIL_PASS=your-aws-secret-access-key
EMAIL_FROM_NAME=GrabGo
EMAIL_FROM_EMAIL=noreply@grabgo.com
```

## Alternative: Gmail Setup

If you prefer to use Gmail:

```env
# Email Service Configuration (Gmail)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
EMAIL_FROM_NAME=GrabGo
```

### Gmail Setup Steps:

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

### SendGrid (Recommended)
```env
EMAIL_HOST=smtp.sendgrid.net
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=apikey
EMAIL_PASS=your-sendgrid-api-key
EMAIL_FROM_NAME=GrabGo
EMAIL_FROM_EMAIL=noreply@yourdomain.com
```

**Note:** `EMAIL_USER` must be exactly `apikey` (lowercase) for SendGrid.

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
EMAIL_SECURE=false
EMAIL_USER=your-aws-access-key-id
EMAIL_PASS=your-aws-secret-access-key
EMAIL_FROM_NAME=GrabGo
EMAIL_FROM_EMAIL=noreply@yourdomain.com
```

**Note:** Replace `us-east-1` with your actual AWS region (e.g., `us-west-2`, `eu-west-1`).

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

