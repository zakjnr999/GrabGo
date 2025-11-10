# How to Get Twilio Credentials - Step by Step

## Step 1: Create/Login to Twilio Account

1. Go to **https://www.twilio.com**
2. Click **"Sign Up"** (if new) or **"Log In"** (if existing)
3. Complete the signup process (you can use a trial account for free)

## Step 2: Get Account SID and Auth Token

### Direct Link: https://console.twilio.com

1. After logging in, you'll be on the **Dashboard**
2. Look at the top of the page - you'll see:
   - **Account SID**: Starts with `AC` (e.g., `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)
   - **Auth Token**: Click the **"Show"** button to reveal it (starts with random characters)

**Where to find it:**
- **Dashboard**: https://console.twilio.com/us1/develop/console
- Look for the section labeled **"Account Info"** or **"Project Info"**
- Your Account SID is always visible
- Your Auth Token is hidden - click **"Show"** to reveal it

**Screenshot locations:**
- Top right corner of the dashboard
- Or in the left sidebar under "Account" → "Account Info"

## Step 3: Get a Twilio Phone Number

### Direct Link: https://console.twilio.com/us1/develop/phone-numbers/manage/incoming

1. In the Twilio Console, click **"Phone Numbers"** in the left sidebar
2. Click **"Manage"** → **"Buy a number"** (or use trial number)
3. Select:
   - **Country**: United States (or your preferred country)
   - **Capabilities**: Check **"SMS"**
   - Click **"Search"**
4. Choose a number and click **"Buy"** (or use free trial number)
5. Copy the full phone number (e.g., `+14155552671`)

**Alternative - Use Trial Number:**
- If you're on a trial account, Twilio may provide a trial number
- Go to: https://console.twilio.com/us1/develop/phone-numbers/manage/incoming
- Look for any existing numbers or click **"Get a number"**

## Step 4: Add to Your .env File

Once you have all three values, add them to your `backend/.env` file:

```env
# Twilio SMS Configuration (for Ghana +233 numbers)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_PHONE_NUMBER=+14155552671
```

**Important Notes:**
- Replace `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` with your actual Account SID
- Replace `your_auth_token_here` with your actual Auth Token
- Replace `+14155552671` with your actual Twilio phone number
- Keep the `+` sign in the phone number

## Quick Links

- **Twilio Console Dashboard**: https://console.twilio.com
- **Account Info**: https://console.twilio.com/us1/account/settings
- **Phone Numbers**: https://console.twilio.com/us1/develop/phone-numbers/manage/incoming
- **API Keys** (optional, for better security): https://console.twilio.com/us1/develop/project/api-keys

## Trial Account Limitations

If you're using a **Trial Account**:
- You can only send SMS to **verified phone numbers**
- To verify a number: https://console.twilio.com/us1/develop/phone-numbers/manage/verified
- Go to **Phone Numbers** → **Verified Caller IDs** → **Add a new number**
- Enter your phone number and verify it via SMS/call

## Troubleshooting

**Can't find Account SID?**
- It's always visible on the dashboard
- Look for a string starting with `AC` followed by 32 characters

**Can't see Auth Token?**
- Click the **"Show"** or **"Reveal"** button next to it
- It will only show once - copy it immediately

**No phone number?**
- Trial accounts may need to verify a number first
- Or purchase a number from the Phone Numbers section
- Make sure it has SMS capability enabled

## Security Warning

⚠️ **NEVER share your Auth Token publicly!**
- Keep it in your `.env` file (which should be in `.gitignore`)
- Don't commit it to Git
- Don't share it in screenshots or messages

