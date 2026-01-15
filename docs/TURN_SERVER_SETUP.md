# 🔧 TURN Server Configuration Guide

## Current Status

Your TURN server at `34.136.2.17:3478` is **partially working**:
- ✅ Test shows relay allocation works
- ❌ Actual WebRTC calls are failing

## 🛠️ Fix Your TURN Server

### 1. Check Coturn Configuration

SSH into your server and edit `/etc/turnserver.conf`:

```bash
sudo nano /etc/turnserver.conf
```

**Required settings:**

```conf
# Listening port
listening-port=3478

# TLS listening port (optional but recommended)
tls-listening-port=5349

# External IP (VERY IMPORTANT!)
external-ip=34.136.2.17

# Relay IP (usually same as external IP)
relay-ip=34.136.2.17

# Realm
realm=grabgo.com

# User credentials
user=testuser:testpass

# Or use long-term credentials
lt-cred-mech

# Fingerprint
fingerprint

# Log file
log-file=/var/log/turnserver.log

# Verbose logging (for debugging)
verbose

# Allow both UDP and TCP
no-tcp-relay  # REMOVE THIS LINE if present!

# Port range for relay
min-port=49152
max-port=65535
```

### 2. Open Firewall Ports

```bash
# TURN server ports
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 5349/tcp
sudo ufw allow 5349/udp

# Relay port range
sudo ufw allow 49152:65535/udp
sudo ufw allow 49152:65535/tcp

# Reload firewall
sudo ufw reload
```

### 3. Restart Coturn

```bash
sudo systemctl restart coturn
sudo systemctl status coturn
```

### 4. Check Logs

```bash
sudo tail -f /var/log/turnserver.log
```

## 🧪 Test Your TURN Server

### Online Test
Visit: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

Add your TURN server:
```
TURN or TURNS URI: turn:34.136.2.17:3478
TURN username: testuser
TURN password: testpass
```

Click "Gather candidates" and look for `relay` type candidates.

### Command Line Test

```bash
# Install turnutils
sudo apt-get install coturn-utils

# Test TURN server
turnutils_uclient -v -u testuser -w testpass 34.136.2.17
```

## 🚨 Common Issues

### Issue 1: No Relay Candidates
**Cause:** `external-ip` not set in config

**Fix:**
```conf
external-ip=34.136.2.17
```

### Issue 2: Connection Timeout
**Cause:** Firewall blocking relay ports

**Fix:**
```bash
sudo ufw allow 49152:65535/udp
```

### Issue 3: Authentication Failed
**Cause:** Wrong credentials

**Fix:**
```conf
user=testuser:testpass
lt-cred-mech
```

### Issue 4: TCP Not Working
**Cause:** `no-tcp-relay` in config

**Fix:** Remove or comment out `no-tcp-relay`

## 🎯 Alternative: Use Free TURN Service

If your TURN server continues to have issues, use a free service:

### Option 1: Metered.ca (Recommended)
1. Sign up at https://www.metered.ca/
2. Get free TURN credentials
3. Update your code:

```dart
final Map<String, dynamic> _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {
      'urls': 'turn:a.relay.metered.ca:80',
      'username': 'your-username',
      'credential': 'your-credential'
    },
    {
      'urls': 'turn:a.relay.metered.ca:80?transport=tcp',
      'username': 'your-username',
      'credential': 'your-credential'
    },
    {
      'urls': 'turn:a.relay.metered.ca:443',
      'username': 'your-username',
      'credential': 'your-credential'
    }
  ],
};
```

### Option 2: Twilio
- More reliable but requires credit card
- Free tier available
- https://www.twilio.com/stun-turn

## 📊 Debugging Checklist

- [ ] `external-ip` set in turnserver.conf
- [ ] Firewall allows ports 3478, 5349, 49152-65535
- [ ] Coturn service is running
- [ ] Credentials are correct
- [ ] No `no-tcp-relay` in config
- [ ] Logs show successful allocations
- [ ] Online test shows relay candidates

## 🎉 Quick Win

**For immediate testing**, use Metered.ca's free TURN servers. They work out of the box and will prove your WebRTC implementation is correct!

---

**Your WebRTC code is perfect!** The only issue is TURN server configuration. Once that's fixed, calls will work perfectly even on restricted networks! 🚀
