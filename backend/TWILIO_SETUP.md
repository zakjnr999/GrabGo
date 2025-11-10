# Twilio SMS Setup for Ghana Phone Numbers

This guide explains how to set up Twilio for sending SMS OTP codes to Ghana (+233) phone numbers.

## Prerequisites

1. Create a Twilio account at [https://www.twilio.com](https://www.twilio.com)
2. Get your Twilio credentials from the Twilio Console

## Setup Steps

### 1. Get Twilio Credentials

1. Log in to your Twilio Console
2. Go to the Dashboard
3. Find your **Account SID** and **Auth Token**
4. Get a **Twilio Phone Number** (you can get a trial number for testing)

### 2. Set Environment Variables

Add the following environment variables to your `.env` file:

```env
# Twilio Configuration for SMS (Ghana +233)
TWILIO_ACCOUNT_SID=your_account_sid_here
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_PHONE_NUMBER=+1234567890  # Your Twilio phone number (e.g., +14155552671)
```

### 3. Example .env File

```env
# Database
MONGODB_URI=mongodb://localhost:27017/grabgo

# JWT
JWT_SECRET=your_jwt_secret_here

# Email (SendGrid)
EMAIL_PASS=your_sendgrid_api_key_here
EMAIL_FROM_EMAIL=noreply@grabgo.com
EMAIL_FROM_NAME=GrabGo

# Twilio SMS (for Ghana +233 numbers)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_PHONE_NUMBER=+14155552671
```

## How It Works

- **Ghana Numbers (+233)**: Uses Twilio to send SMS
- **US Numbers**: Uses SendGrid email-to-SMS gateway (if configured)

## Testing

1. Make sure your `.env` file has the Twilio credentials
2. Restart your server
3. Try sending an OTP to a Ghana phone number
4. Check the server logs for confirmation

## Troubleshooting

### Error: "Twilio not configured"
- Make sure `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN` are set in your `.env` file
- Restart your server after adding the variables

### Error: "Twilio phone number not configured"
- Make sure `TWILIO_PHONE_NUMBER` is set in your `.env` file
- The phone number should include the country code (e.g., `+14155552671`)

### SMS Not Received
- Check your Twilio account balance
- Verify the phone number format is correct (+233XXXXXXXXX)
- Check Twilio Console for message logs and errors

## Twilio Trial Account

- Twilio trial accounts have limitations
- You can only send SMS to verified phone numbers
- Upgrade to a paid account for production use

## Production Considerations

- Upgrade to a paid Twilio account
- Set up proper error handling and monitoring
- Consider rate limiting for SMS sending
- Monitor Twilio usage and costs

