const nodemailer = require('nodemailer');
const crypto = require('crypto');

// Create reusable transporter object using SMTP transport
const createTransporter = () => {
  // For development, you can use Gmail or other SMTP services
  // For production, use a service like SendGrid, Mailgun, or AWS SES
  
  // Check if email credentials are configured
  console.log('📧 Checking email configuration...');
  console.log('EMAIL_HOST:', process.env.EMAIL_HOST ? `✅ Set (${process.env.EMAIL_HOST})` : '❌ Missing');
  console.log('EMAIL_USER:', process.env.EMAIL_USER ? `✅ Set (${process.env.EMAIL_USER})` : '❌ Missing');
  console.log('EMAIL_PASS:', process.env.EMAIL_PASS ? '✅ Set (****)' : '❌ Missing');
  console.log('EMAIL_PORT:', process.env.EMAIL_PORT || '587 (default)');
  console.log('EMAIL_SECURE:', process.env.EMAIL_SECURE || 'false (default)');
  
  if (!process.env.EMAIL_HOST || !process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
    console.warn('⚠️  Email service not configured. Email sending will be disabled.');
    console.warn('⚠️  Please set EMAIL_HOST, EMAIL_USER, and EMAIL_PASS in your .env file');
    return null;
  }

  console.log('✅ Email service configured. Creating transporter...');
  
  const transporterConfig = {
    host: process.env.EMAIL_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.EMAIL_PORT || '587'),
    secure: process.env.EMAIL_SECURE === 'true', // true for 465, false for other ports
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
    // Add debug logging
    debug: true,
    logger: true,
  };
  
  console.log('📧 Transporter config:', {
    host: transporterConfig.host,
    port: transporterConfig.port,
    secure: transporterConfig.secure,
    user: transporterConfig.auth.user,
    pass: '****',
  });
  
  return nodemailer.createTransport(transporterConfig);
};

// Generate email verification token
const generateVerificationToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

// Generate 6-digit OTP code
const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// Send email verification email with OTP
const sendVerificationEmail = async (email, username, otp) => {
  console.log('📧 Attempting to send verification email...');
  console.log('To:', email);
  console.log('Username:', username);
  console.log('OTP:', otp);
  
  try {
    const transporter = createTransporter();
    
    if (!transporter) {
      console.warn('⚠️  Email service not configured. Skipping email send.');
      return { success: false, message: 'Email service not configured' };
    }
    
    console.log('✅ Transporter created. Preparing email...');

    const mailOptions = {
      from: `"${process.env.EMAIL_FROM_NAME || 'GrabGo'}" <${process.env.EMAIL_USER}>`,
      to: email,
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

    console.log('📤 Sending email...');
    try {
      const info = await transporter.sendMail(mailOptions);
      console.log('✅ Verification email sent successfully!');
      console.log('Message ID:', info.messageId);
      console.log('Response:', info.response);
      console.log('Accepted:', info.accepted);
      console.log('Rejected:', info.rejected);
      return { success: true, messageId: info.messageId };
    } catch (sendError) {
      console.error('❌ Error during sendMail:', sendError);
      throw sendError; // Re-throw to be caught by outer catch
    }
  } catch (error) {
    console.error('❌ Error sending verification email:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      command: error.command,
      response: error.response,
      responseCode: error.responseCode,
      stack: error.stack,
    });
    return { success: false, error: error.message };
  }
};

// Send password reset email
const sendPasswordResetEmail = async (email, username, token) => {
  try {
    const transporter = createTransporter();
    
    if (!transporter) {
      console.warn('⚠️  Email service not configured. Skipping email send.');
      return { success: false, message: 'Email service not configured' };
    }

    const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password?token=${token}`;

    const mailOptions = {
      from: `"${process.env.EMAIL_FROM_NAME || 'GrabGo'}" <${process.env.EMAIL_USER}>`,
      to: email,
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

    const info = await transporter.sendMail(mailOptions);
    console.log('✅ Password reset email sent:', info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('❌ Error sending password reset email:', error);
    return { success: false, error: error.message };
  }
};

module.exports = {
  generateVerificationToken,
  generateOTP,
  sendVerificationEmail,
  sendPasswordResetEmail,
};

