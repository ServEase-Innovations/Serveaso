# iOS Build Error 70 - Troubleshooting Guide

## Error
```
error Failed to build ios project. "xcodebuild" exited with error code '70'.
```

## What Error Code 70 Means
Error code 70 typically indicates one of these issues:
1. **Code signing / provisioning profile problems**
2. **Certificate expired or not trusted**
3. **Device not registered in Apple Developer account**
4. **Missing or invalid entitlements**
5. **Xcode automatic signing issues**

## Quick Diagnostics

### 1. Check Current Configuration
Your project is configured with:
- **Code Signing**: Automatic
- **Development Team**: 9RXM3W27X2
- **Device**: Ronit's iPhone (00008120-001815D22690C01E)

### 2. Verify Environment
```bash
cd /Users/ronit/Desktop/serveaso/Serveaso-BE/apps/servease-ios
npx react-native doctor
```

## Solutions (Try in Order)

### Solution 1: Open Xcode and Check Signing (RECOMMENDED)

This will show you the exact error:

```bash
cd /Users/ronit/Desktop/serveaso/Serveaso-BE/apps/servease-ios/ios
open Serveaso.xcworkspace
```

In Xcode:
1. Select **Serveaso** project in left sidebar
2. Select **Serveaso** target
3. Go to **Signing & Capabilities** tab
4. Check for red errors or warnings
5. Common issues:
   - ❌ "Failed to register bundle identifier" → Bundle ID conflict
   - ❌ "No profile matching..." → Need to create provisioning profile
   - ❌ "Provisioning profile doesn't include device" → Device not registered
   - ❌ "Certificate expired" → Renew certificate in Apple Developer

**Fix in Xcode:**
- Ensure "Automatically manage signing" is checked
- Select the correct Team (9RXM3W27X2 or your Apple ID)
- If errors persist, click "Download Manual Profiles"

### Solution 2: Test with Simulator First

Skip device signing issues by testing on simulator:

```bash
cd /Users/ronit/Desktop/serveaso/Serveaso-BE/apps/servease-ios

# Run on iPhone 16 Pro simulator
npm run ios -- --simulator="iPhone 16 Pro"
```

If this works, the issue is definitely device signing.

### Solution 3: Clean and Rebuild

```bash
cd /Users/ronit/Desktop/serveaso/Serveaso-BE/apps/servease-ios

# Clean all build artifacts
rm -rf ios/build
rm -rf ios/Pods
rm -rf node_modules

# Reinstall dependencies
npm install
cd ios && pod install && cd ..

# Try building again
npm run ios
```

### Solution 4: Check Device Registration

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/devices/list)
2. Check if **Ronit's iPhone (00008120-001815D22690C01E)** is registered
3. If not, add it:
   - Click "+" button
   - Enter device name and UDID
   - UDID: `00008120-001815D22690C01E`

### Solution 5: Reset Provisioning Profiles

```bash
# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Delete provisioning profiles
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
```

Then open Xcode and let it regenerate profiles automatically.

### Solution 6: Check Bundle Identifier

Open `ios/Serveaso/Info.plist` and verify:
```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
```

In Xcode, check the Bundle Identifier matches your Apple Developer account app ID.

### Solution 7: Trust Certificate on Mac

If you recently added a certificate:

```bash
# Open Keychain Access
open /Applications/Utilities/Keychain\ Access.app
```

1. Search for "Apple Development" or "iPhone Developer"
2. Double-click the certificate
3. Expand "Trust" section
4. Set "Code Signing" to "Always Trust"

### Solution 8: Manual Signing (Last Resort)

In Xcode:
1. Go to **Signing & Capabilities**
2. Uncheck "Automatically manage signing"
3. Select your provisioning profile manually
4. Select your certificate manually

## Quick Test Commands

### Run on Simulator (Recommended First)
```bash
cd /Users/ronit/Desktop/serveaso/Serveaso-BE/apps/servease-ios
npm run ios -- --simulator="iPhone 16 Pro"
```

### Run on Physical Device
```bash
npm run ios -- --device "Ronit's iPhone"
```

### Build with Detailed Logs
```bash
cd ios
xcodebuild -workspace Serveaso.xcworkspace \
  -scheme Serveaso \
  -configuration Debug \
  -destination 'id=00008120-001815D22690C01E' \
  clean build \
  | tee build.log
```

Check `build.log` for detailed error messages.

## Most Likely Causes (Based on Error 70)

1. **Device not in provisioning profile** (80% chance)
   - Fix: Register device in Apple Developer Portal
   
2. **Certificate expired** (10% chance)
   - Fix: Renew certificate in Xcode preferences → Accounts → Manage Certificates
   
3. **Wrong team selected** (5% chance)
   - Fix: Select correct team in Xcode signing settings
   
4. **Bundle ID conflict** (5% chance)
   - Fix: Change bundle identifier or remove conflicting app from Apple Developer

## Get Detailed Error

The best way to see the actual error:

```bash
cd /Users/ronit/Desktop/serveaso/Serveaso-BE/apps/servease-ios/ios
open Serveaso.xcworkspace
```

Then:
1. Select a destination device (your iPhone or simulator)
2. Press **⌘ + B** to build
3. If it fails, check the **Issue Navigator** (⌘ + 5) for detailed errors
4. Look for errors related to:
   - Code signing
   - Provisioning profiles
   - Certificates
   - Entitlements

## Environment Check

Your current setup:
- ✅ Xcode installed
- ✅ CocoaPods installed
- ✅ Node.js and npm working
- ✅ Pods installed successfully
- ❓ Code signing configuration (needs verification in Xcode)

## Next Steps

1. **Open Xcode** and check Signing & Capabilities
2. If that shows errors, fix them in Xcode's UI
3. If no errors shown in Xcode, try running from Xcode directly (⌘ + R)
4. If still failing, test with simulator first
5. Share the specific error message from Xcode for more targeted help

## Common Error Messages and Fixes

| Error in Xcode | Solution |
|---------------|----------|
| "Failed to register bundle identifier" | Change bundle ID or remove from Apple Developer |
| "Provisioning profile doesn't support capability" | Add capability to App ID in Apple Developer |
| "Certificate has expired" | Renew certificate in Xcode → Preferences → Accounts |
| "Device not included in profile" | Register device in Apple Developer Portal |
| "No profiles for 'com.yourapp' were found" | Let Xcode create one automatically |
| "An App ID with Identifier already exists" | Use existing App ID or choose different one |

## Support Resources

- [Apple Developer Documentation - Code Signing](https://developer.apple.com/support/code-signing/)
- [React Native - Running on Device](https://reactnative.dev/docs/running-on-device)
- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)

---

**TL;DR**: Open the project in Xcode, check Signing & Capabilities, and the exact error will be shown there. Error 70 is almost always a signing issue that Xcode's UI can diagnose and often auto-fix.
