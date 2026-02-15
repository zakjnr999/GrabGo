const sgMail = require('@sendgrid/mail');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const twilio = require('twilio');

// Initialize SendGrid (used for legacy email-to-SMS only)
const initializeSendGrid = () => {
  const sendgridApiKey = process.env.SENDGRID_API_KEY || process.env.EMAIL_PASS;
  if (!sendgridApiKey) {
    return false;
  }

  sgMail.setApiKey(sendgridApiKey);
  return true;
};

// Initialize SMTP transporter (email)
let smtpTransporter = null;

const initializeSmtpTransporter = () => {
  if (smtpTransporter) {
    return smtpTransporter;
  }

  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const port = Number(process.env.SMTP_PORT || 587);

  if (!host || !user || !pass) {
    return null;
  }

  smtpTransporter = nodemailer.createTransport({
    host,
    port,
    secure: process.env.SMTP_SECURE === 'true' || port === 465,
    auth: { user, pass },
    connectionTimeout: 30000,
    greetingTimeout: 30000,
    socketTimeout: 30000,
  });

  return smtpTransporter;
};

const getSmtpFrom = () => {
  const fromEmail =
    process.env.SMTP_FROM_EMAIL ||
    process.env.EMAIL_FROM_EMAIL ||
    process.env.SMTP_USER ||
    'noreply@grabgo.com';
  const fromName =
    process.env.SMTP_FROM_NAME ||
    process.env.EMAIL_FROM_NAME ||
    'GrabGo';

  return `${fromName} <${fromEmail}>`;
};

const isSmtpConfigured = () => {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
};

const sendEmailViaSmtp = async ({ to, subject, html, text }) => {
  try {
    const transporter = initializeSmtpTransporter();
    if (!transporter) {
      return {
        success: false,
        message: 'SMTP email service not configured',
      };
    }

    const from = getSmtpFrom();
    const maxRetries = 3;
    let lastError;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const info = await transporter.sendMail({
          from,
          to,
          subject,
          html,
          text,
        });

        return {
          success: true,
          messageId: info?.messageId || 'sent',
          accepted: info?.accepted || [],
          rejected: info?.rejected || [],
        };
      } catch (sendError) {
        lastError = sendError;
        const responseCode = sendError?.responseCode;
        const message = String(sendError?.message || '').toLowerCase();
        const isRetryable =
          sendError?.code === 'ETIMEDOUT' ||
          sendError?.code === 'ESOCKET' ||
          sendError?.code === 'ECONNECTION' ||
          message.includes('timeout') ||
          responseCode === 421 ||
          responseCode === 450 ||
          responseCode === 451 ||
          responseCode === 452;

        if (isRetryable && attempt < maxRetries) {
          const waitTime = attempt * 2000;
          await new Promise(resolve => setTimeout(resolve, waitTime));
          continue;
        }

        throw sendError;
      }
    }

    throw lastError;
  } catch (error) {
    const errorMessage = error?.message || 'Failed to send email';
    console.error('Error sending email via SMTP:', errorMessage);
    return { success: false, error: errorMessage };
  }
};

const verifyEmailService = async () => {
  if (!isSmtpConfigured()) {
    return {
      success: false,
      configured: false,
      message: 'SMTP is not configured',
    };
  }

  try {
    const transporter = initializeSmtpTransporter();
    if (!transporter) {
      return {
        success: false,
        configured: false,
        message: 'SMTP is not configured',
      };
    }

    await transporter.verify();

    return {
      success: true,
      configured: true,
      message: 'SMTP connection verified',
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: process.env.SMTP_SECURE === 'true' || Number(process.env.SMTP_PORT || 587) === 465,
      from: getSmtpFrom(),
    };
  } catch (error) {
    return {
      success: false,
      configured: true,
      message: 'SMTP connection failed',
      error: error.message,
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: process.env.SMTP_SECURE === 'true' || Number(process.env.SMTP_PORT || 587) === 465,
      from: getSmtpFrom(),
    };
  }
};

// Initialize Twilio client
const initializeTwilio = () => {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  
  if (!accountSid || !authToken) {
    return null;
  }
  
  return twilio(accountSid, authToken);
};

// Generate email verification token
const generateVerificationToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

// Generate 6-digit OTP code
const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const escapeHtml = (value = '') => {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
};

const getEmailBranding = () => {
  const brandName = process.env.EMAIL_BRAND_NAME || 'GrabGo';
  const logoUrl = (process.env.EMAIL_LOGO_URL || '').trim();
  return { brandName, logoUrl };
};

const buildEmailLayout = ({ preheader, heading, subheading, bodyHtml }) => {
  const year = new Date().getFullYear();
  const { brandName, logoUrl } = getEmailBranding();
  const logoBlock = logoUrl
    ? `<img src="${escapeHtml(
        logoUrl
      )}" alt="${escapeHtml(
        brandName
      )} logo" width="44" height="44" style="display:block;width:44px;height:44px;border-radius:12px;border:0;outline:none;text-decoration:none;">`
    : `<div style="width:44px;height:44px;border-radius:12px;background:#ffffff;color:#ff5a2c;font-size:18px;line-height:44px;font-weight:700;text-align:center;">GG</div>`;

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(heading)}</title>
</head>
<body style="margin:0;padding:0;background:#f4f6f8;font-family:Arial,sans-serif;color:#1f2937;">
  <span style="display:none!important;visibility:hidden;opacity:0;height:0;width:0;overflow:hidden;">
    ${escapeHtml(preheader)}
  </span>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f6f8;padding:24px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#ffffff;border-radius:16px;overflow:hidden;">
          <tr>
            <td style="background:#ff5a2c;padding:24px 28px;">
              ${logoBlock}
              <div style="margin-top:10px;font-size:24px;line-height:1.2;font-weight:700;color:#ffffff;">${escapeHtml(
                brandName
              )}</div>
              <div style="margin-top:8px;font-size:20px;line-height:1.3;font-weight:700;color:#ffffff;">${escapeHtml(
                heading
              )}</div>
              <div style="margin-top:6px;font-size:14px;line-height:1.5;color:#ffe8de;">${escapeHtml(
                subheading
              )}</div>
            </td>
          </tr>
          <tr>
            <td style="padding:24px 28px;">
              ${bodyHtml}
            </td>
          </tr>
          <tr>
            <td style="padding:0 28px 24px 28px;">
              <div style="border-top:1px solid #e5e7eb;padding-top:16px;font-size:12px;color:#6b7280;text-align:center;">
                © ${year} GrabGo. All rights reserved.
              </div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
};

// Send email verification email with OTP using SMTP
const sendVerificationEmail = async (email, username, otp) => {
  try {
    const subject = 'Verify Your Email Address - GrabGo Delivery';
    const safeUsername = escapeHtml(username || 'there');
    const safeOtp = escapeHtml(otp);
    const html = buildEmailLayout({
      preheader: 'Your GrabGo verification code',
      heading: 'Verify your email',
      subheading: 'Complete your signup securely',
      bodyHtml: `
        <p style="margin:0 0 14px 0;font-size:15px;line-height:1.6;color:#111827;">Hi ${safeUsername},</p>
        <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#374151;">
          Thanks for signing up with GrabGo. Use the code below to verify your email address.
        </p>
        <div style="text-align:center;margin:22px 0;">
          <div style="display:inline-block;background:#fff3ee;border:1px solid #ffd8cc;color:#ff5a2c;padding:14px 24px;border-radius:12px;font-size:32px;line-height:1;font-weight:700;letter-spacing:6px;font-family:'Courier New',monospace;">
            ${safeOtp}
          </div>
        </div>
        <p style="margin:0 0 10px 0;font-size:14px;line-height:1.6;color:#4b5563;">
          This code expires in <strong>10 minutes</strong>.
        </p>
        <p style="margin:0;font-size:13px;line-height:1.6;color:#6b7280;">
          If you didn’t create an account, you can safely ignore this email.
        </p>
      `,
    });
    const text = `
Hi ${username || 'there'},

Thanks for signing up with GrabGo. Use the code below to verify your email address.

Verification code: ${otp}

This code expires in 10 minutes.

If you didn’t create an account, you can safely ignore this email.
`;
    return await sendEmailViaSmtp({
      to: email,
      subject,
      html,
      text,
    });
  } catch (error) {
    console.error('Error sending verification email:', error.message);
    return { success: false, error: error.message };
  }
};

// Send password reset email using SMTP
const sendPasswordResetEmail = async (email, username, token) => {
  try {
    const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password?token=${token}`;
    const subject = 'Reset Your Password - GrabGo';
    const safeUsername = escapeHtml(username || 'there');
    const safeResetUrl = escapeHtml(resetUrl);
    const html = buildEmailLayout({
      preheader: 'Reset your GrabGo password',
      heading: 'Password reset request',
      subheading: 'Secure your account',
      bodyHtml: `
        <p style="margin:0 0 14px 0;font-size:15px;line-height:1.6;color:#111827;">Hi ${safeUsername},</p>
        <p style="margin:0 0 18px 0;font-size:15px;line-height:1.6;color:#374151;">
          We received a request to reset your GrabGo password.
        </p>
        <div style="margin:0 0 20px 0;">
          <a href="${safeResetUrl}" style="display:inline-block;background:#ff5a2c;color:#ffffff;text-decoration:none;padding:12px 22px;border-radius:10px;font-size:14px;font-weight:700;">
            Reset Password
          </a>
        </div>
        <p style="margin:0 0 8px 0;font-size:14px;line-height:1.6;color:#4b5563;">
          This link expires in <strong>1 hour</strong>.
        </p>
        <p style="margin:0 0 8px 0;font-size:13px;line-height:1.6;color:#6b7280;">
          If the button doesn’t work, copy and paste this link into your browser:
        </p>
        <p style="margin:0;word-break:break-all;font-size:12px;line-height:1.6;color:#ff5a2c;">
          ${safeResetUrl}
        </p>
      `,
    });
    const text = `
Hi ${username || 'there'},

We received a request to reset your GrabGo password.

Reset link:
${resetUrl}

This link expires in 1 hour.
If you didn’t request a reset, you can ignore this email.
`;
    return await sendEmailViaSmtp({
      to: email,
      subject,
      html,
      text,
    });
  } catch (error) {
    console.error('Error sending password reset email:', error.message);
    return { success: false, error: error.message };
  }
};

// Send SMS via SendGrid email-to-SMS gateway
// Note: SendGrid doesn't have native SMS support, so we use email-to-SMS gateways
// For production, consider using Twilio or AWS SNS for better reliability
const sendSMS = async (phoneNumber, otp) => {
  try {
    if (!initializeSendGrid()) {
      console.error('❌ SMS service not configured - SENDGRID_API_KEY is missing');
      return { success: false, message: 'SMS service not configured' };
    }

    const fromEmail = process.env.EMAIL_FROM_EMAIL || 'noreply@grabgo.com';
    const fromName = process.env.EMAIL_FROM_NAME || 'GrabGo';

    // Format phone number for SMS
    // Note: Email-to-SMS gateways only work for US carriers
    // For Ghana (+233) and other international numbers, you need a proper SMS service like Twilio
    const cleanPhone = phoneNumber.replace(/[^0-9+]/g, '');
    
    // Check if it's a Ghana phone number (+233)
    const isGhanaNumber = cleanPhone.startsWith('233') || cleanPhone.startsWith('+233');
    
    if (isGhanaNumber) {
      // Format Ghana phone number for Twilio
      let ghanaPhone = cleanPhone.replace(/[^0-9]/g, '');
      
      // If it starts with 0, replace with 233 (local format to international)
      if (ghanaPhone.startsWith('0')) {
        ghanaPhone = `233${ghanaPhone.substring(1)}`;
      } else if (!ghanaPhone.startsWith('233')) {
        ghanaPhone = `233${ghanaPhone}`;
      }
      
      // Ensure it starts with + for Twilio
      const formattedGhanaPhone = `+${ghanaPhone}`;
      
      console.log(`📱 Ghana phone number detected: ${formattedGhanaPhone}`);
      
      // Try to use Twilio for Ghana numbers
      const twilioClient = initializeTwilio();
      if (!twilioClient) {
        console.error('❌ Twilio not configured - TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN required for Ghana numbers');
        return {
          success: false,
          error: 'Twilio not configured. Please set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN environment variables.',
          message: 'For Ghana phone numbers, Twilio SMS service is required.',
        };
      }
      
      const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;
      if (!twilioPhoneNumber) {
        console.error('❌ Twilio phone number not configured - TWILIO_PHONE_NUMBER required');
        return {
          success: false,
          error: 'Twilio phone number not configured. Please set TWILIO_PHONE_NUMBER environment variable.',
          message: 'Twilio phone number is required to send SMS.',
        };
      }
      
      // Validate Twilio phone number format (should be a US number starting with +1)
      const cleanTwilioNumber = twilioPhoneNumber.replace(/[^0-9+]/g, '');
      if (!cleanTwilioNumber.startsWith('+1') && !cleanTwilioNumber.startsWith('1')) {
        console.error(`❌ Invalid Twilio phone number format: ${twilioPhoneNumber}`);
        console.error('⚠️  Twilio phone numbers must be US numbers (starting with +1)');
        console.error('💡 You can use a US Twilio number to send SMS to Ghana numbers');
        return {
          success: false,
          error: `Invalid Twilio phone number format: ${twilioPhoneNumber}. Twilio phone numbers must be US numbers (starting with +1).`,
          message: 'Please use a US Twilio phone number (e.g., +14155552671). You can get one from the Twilio Console.',
        };
      }
      
      // Ensure Twilio number starts with +1
      const formattedTwilioNumber = cleanTwilioNumber.startsWith('+') 
        ? cleanTwilioNumber 
        : `+${cleanTwilioNumber}`;
      
      // Prevent sending to the same number
      if (formattedTwilioNumber === formattedGhanaPhone) {
        console.error(`❌ Cannot use Ghana number as Twilio sender: ${formattedGhanaPhone}`);
        return {
          success: false,
          error: 'Cannot use a Ghana phone number as the Twilio sender. Please use a US Twilio number (starting with +1).',
          message: 'Twilio phone numbers must be US numbers. Get a US number from Twilio Console to send SMS to Ghana.',
        };
      }
      
      try {
        console.log(`📤 Sending SMS via Twilio from ${formattedTwilioNumber} to ${formattedGhanaPhone}...`);
        const message = await twilioClient.messages.create({
          body: `Your GrabGo verification code is: ${otp}. This code will expire in 10 minutes.`,
          from: formattedTwilioNumber,
          to: formattedGhanaPhone,
        });
        
        console.log(`✅ SMS sent successfully via Twilio. Message SID: ${message.sid}`);
        return { 
          success: true, 
          messageId: message.sid,
          provider: 'twilio',
        };
      } catch (twilioError) {
        console.error('❌ Twilio SMS error:', {
          message: twilioError.message,
          code: twilioError.code,
          status: twilioError.status,
        });
        return {
          success: false,
          error: twilioError.message,
          code: twilioError.code,
          details: `Twilio error: ${twilioError.message}`,
        };
      }
    }
    
    // Handle US phone numbers (for email-to-SMS gateway)
    let formattedPhone = cleanPhone.replace(/^\+?1/, ''); // Remove US country code if present
    
    // Ensure phone number has country code (assume US if missing)
    if (formattedPhone.length === 10) {
      formattedPhone = `1${formattedPhone}`; // Add US country code
    }
    
    // Try multiple carrier gateways (most common ones)
    const carriers = [
      '@txt.att.net',      // AT&T
      '@vtext.com',        // Verizon
      '@tmomail.net',      // T-Mobile
      '@messaging.sprintpcs.com', // Sprint
      '@msg.fi.google.com', // Google Fi
    ];

    // Use first carrier as default (AT&T)
    const smsEmail = `${formattedPhone}${carriers[0]}`;
    
    console.log(`📧 Sending SMS via email-to-SMS gateway (US only): ${smsEmail}`);
    
    const msg = {
      to: smsEmail,
      from: {
        email: fromEmail,
        name: fromName,
      },
      subject: 'GrabGo Verification Code',
      text: `Your GrabGo verification code is: ${otp}. This code will expire in 10 minutes.`,
    };

    // Retry logic for connection timeouts
    const maxRetries = 3;
    let lastError;
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const sendPromise = sgMail.send(msg);
        const timeoutPromise = new Promise((_, reject) => {
          setTimeout(() => reject(new Error('SMS sending timeout after 30 seconds')), 30000);
        });
        
        const [response] = await Promise.race([sendPromise, timeoutPromise]);
        console.log(`✅ SMS sent successfully via SendGrid. Message ID: ${response.headers['x-message-id'] || 'sent'}`);
        return { success: true, messageId: response.headers['x-message-id'] || 'sent' };
      } catch (sendError) {
        lastError = sendError;
        console.warn(`⚠️  SMS send attempt ${attempt}/${maxRetries} failed:`, sendError.message);
        
        // If it's a connection timeout or rate limit and we have retries left, wait and retry
        if (
          (sendError.code === 'ETIMEDOUT' || 
           sendError.message.includes('timeout') ||
           sendError.code === 429) && 
          attempt < maxRetries
        ) {
          const waitTime = attempt * 2000; // 2s, 4s, 6s
          console.log(`⏳ Retrying SMS send in ${waitTime}ms...`);
          await new Promise(resolve => setTimeout(resolve, waitTime));
          continue;
        }
        
        // If it's not a retryable error or we're out of retries, break and throw
        throw sendError;
      }
    }
    
    // If we get here, all retries failed
    throw lastError;
  } catch (error) {
    console.error('❌ Error sending SMS:', {
      message: error.message,
      code: error.code,
      response: error.response?.body,
      phoneNumber: phoneNumber,
    });
    return { success: false, error: error.message, details: error.response?.body };
  }
};

module.exports = {
  generateVerificationToken,
  generateOTP,
  verifyEmailService,
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendSMS,
};
