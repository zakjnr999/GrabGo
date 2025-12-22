# Admin User Creation Scripts

This directory contains utility scripts for managing admin users.

## Create Admin User

### Usage

1. **Edit the script** `createAdmin.js` and update these values:
   ```javascript
   const ADMIN_EMAIL = 'admin@grabgo.com';
   const ADMIN_PASSWORD = 'Admin@123456'; // Change this!
   const ADMIN_USERNAME = 'admin';
   ```

2. **Run the script** from the backend directory:
   ```bash
   node scripts/createAdmin.js
   ```

3. **Save the credentials** that are displayed in the console

### Features
- ✅ Checks if admin already exists
- ✅ Hashes password with bcrypt
- ✅ Sets proper admin flags (role: 'admin', isAdmin: true)
- ✅ Verifies email automatically
- ✅ Displays credentials after creation

### Security Notes
- Always use a strong password
- Never commit credentials to git
- Change the default password after first login
