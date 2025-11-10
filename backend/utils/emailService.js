const sgMail = require('@sendgrid/mail');
const crypto = require('crypto');

// Initialize SendGrid
const initializeSendGrid = () => {
  if (!process.env.EMAIL_PASS) {
    return false;
  }

  sgMail.setApiKey(process.env.EMAIL_PASS);
  return true;
};

// Generate email verification token
const generateVerificationToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

// Generate 6-digit OTP code
const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// Send email verification email with OTP using SendGrid API
const sendVerificationEmail = async (email, username, otp) => {
  try {
    if (!initializeSendGrid()) {
      return { success: false, message: 'Email service not configured' };
    }

    const fromEmail = process.env.EMAIL_FROM_EMAIL || 'noreply@grabgo.com';
    const fromName = process.env.EMAIL_FROM_NAME || 'GrabGo';

    const msg = {
      to: email,
      from: {
        email: fromEmail,
        name: fromName,
      },
      subject: 'Verify Your Email Address - GrabGo',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Verify Your Email</title>
        </head>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
            <h1 style="color: white; margin: 0;">GrabGo</h1>
          </div>
          <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
            <h2 style="color: #333; margin-top: 0;">Hello ${username}!</h2>
            <p>Thank you for signing up with GrabGo. Please verify your email address to complete your registration.</p>
            <p>Your verification code is:</p>
            <div style="text-align: center; margin: 30px 0;">
              <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                          color: white; 
                          padding: 20px 30px; 
                          border-radius: 10px; 
                          display: inline-block;
                          font-size: 32px;
                          font-weight: bold;
                          letter-spacing: 8px;
                          font-family: 'Courier New', monospace;">
                ${otp}
              </div>
            </div>
            <p style="color: #666; font-size: 14px; margin-top: 30px;">
              Enter this code in the app to verify your email address. This code will expire in 10 minutes.
            </p>
            <p style="color: #999; font-size: 12px; margin-top: 20px;">
              If you didn't create an account with GrabGo, please ignore this email.
            </p>
            <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">
              © ${new Date().getFullYear()} GrabGo. All rights reserved.
            </p>
          </div>
        </body>
        </html>
      `,
      text: `
        Hello ${username}!
        
        Thank you for signing up with GrabGo. Please verify your email address to complete your registration.
        
        Your verification code is: ${otp}
        
        Enter this code in the app to verify your email address. This code will expire in 10 minutes.
        
        If you didn't create an account with GrabGo, please ignore this email.
        
        © ${new Date().getFullYear()} GrabGo. All rights reserved.
      `,
    };

    // Retry logic for connection timeouts
    const maxRetries = 3;
    let lastError;
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const sendPromise = sgMail.send(msg);
        const timeoutPromise = new Promise((_, reject) => {
          setTimeout(() => reject(new Error('Email sending timeout after 30 seconds')), 30000);
        });
        
        const [response] = await Promise.race([sendPromise, timeoutPromise]);
        return { success: true, messageId: response.headers['x-message-id'] || 'sent' };
      } catch (sendError) {
        lastError = sendError;
        
        // If it's a connection timeout or rate limit and we have retries left, wait and retry
        if (
          (sendError.code === 'ETIMEDOUT' || 
           sendError.message.includes('timeout') ||
           sendError.code === 429) && 
          attempt < maxRetries
        ) {
          const waitTime = attempt * 2000; // 2s, 4s, 6s
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
    console.error('Error sending verification email:', error.message);
    return { success: false, error: error.message };
  }
};

// Send password reset email using SendGrid API
const sendPasswordResetEmail = async (email, username, token) => {
  try {
    if (!initializeSendGrid()) {
      return { success: false, message: 'Email service not configured' };
    }

    const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password?token=${token}`;
    const fromEmail = process.env.EMAIL_FROM_EMAIL || 'noreply@grabgo.com';
    const fromName = process.env.EMAIL_FROM_NAME || 'GrabGo';

    const msg = {
      to: email,
      from: {
        email: fromEmail,
        name: fromName,
      },
      subject: 'Reset Your Password - GrabGo',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Reset Your Password</title>
        </head>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
            <h1 style="color: white; margin: 0;">GrabGo</h1>
          </div>
          <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
            <h2 style="color: #333; margin-top: 0;">Hello ${username}!</h2>
            <p>You requested to reset your password for your GrabGo account.</p>
            <p>Click the button below to reset your password:</p>
            <div style="text-align: center; margin: 30px 0;">
              <a href="${resetUrl}" 
                 style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                        color: white; 
                        padding: 15px 30px; 
                        text-decoration: none; 
                        border-radius: 5px; 
                        display: inline-block;
                        font-weight: bold;">
                Reset Password
              </a>
            </div>
            <p style="color: #666; font-size: 14px;">Or copy and paste this link into your browser:</p>
            <p style="color: #667eea; word-break: break-all; font-size: 12px;">${resetUrl}</p>
            <p style="color: #666; font-size: 14px; margin-top: 30px;">
              This link will expire in 1 hour. If you didn't request a password reset, please ignore this email.
            </p>
            <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">
              © ${new Date().getFullYear()} GrabGo. All rights reserved.
            </p>
          </div>
        </body>
        </html>
      `,
      text: `
        Hello ${username}!
        
        You requested to reset your password for your GrabGo account.
        
        Click this link to reset your password:
        ${resetUrl}
        
        This link will expire in 1 hour. If you didn't request a password reset, please ignore this email.
        
        © ${new Date().getFullYear()} GrabGo. All rights reserved.
      `,
    };

    const [response] = await sgMail.send(msg);
    return { success: true, messageId: response.headers['x-message-id'] || 'sent' };
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
      return { success: false, message: 'SMS service not configured' };
    }

    const fromEmail = process.env.EMAIL_FROM_EMAIL || 'noreply@grabgo.com';
    const fromName = process.env.EMAIL_FROM_NAME || 'GrabGo';

    // Format phone number for email-to-SMS gateway
    // Common carriers: @txt.att.net (AT&T), @vtext.com (Verizon), @tmomail.net (T-Mobile), etc.
    // This is a simplified approach - in production, you'd want to detect carrier or use a service like Twilio
    const cleanPhone = phoneNumber.replace(/[^0-9]/g, '');
    
    // Try multiple carrier gateways (most common ones)
    const carriers = [
      '@txt.att.net',      // AT&T
      '@vtext.com',        // Verizon
      '@tmomail.net',      // T-Mobile
      '@messaging.sprintpcs.com', // Sprint
      '@msg.fi.google.com', // Google Fi
    ];

    // Use first carrier as default (AT&T)
    const smsEmail = `${cleanPhone}${carriers[0]}`;
    
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
        return { success: true, messageId: response.headers['x-message-id'] || 'sent' };
      } catch (sendError) {
        lastError = sendError;
        
        // If it's a connection timeout or rate limit and we have retries left, wait and retry
        if (
          (sendError.code === 'ETIMEDOUT' || 
           sendError.message.includes('timeout') ||
           sendError.code === 429) && 
          attempt < maxRetries
        ) {
          const waitTime = attempt * 2000; // 2s, 4s, 6s
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
    console.error('Error sending SMS:', error.message);
    return { success: false, error: error.message };
  }
};

module.exports = {
  generateVerificationToken,
  generateOTP,
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendSMS,
};
