# OmniCare - Verification Screens Image Guide

## 📁 Image Placement Instructions

All images should be placed in the following directory:
```
/Users/rouge/Desktop/omniCare/OmniCareApp/assets/images/
```

Create the `images` folder inside `assets` if it doesn't exist.

---

## 🎨 Image Specifications

### **General Requirements:**
- **Format**: PNG with transparent background
- **Size**: 400x400px (will be displayed at 140x140px)
- **Style**: Flat illustration, modern, friendly, medical theme
- **Colors**: Use OmniCare brand colors (Seafoam Green #1FBF9A, Deep Teal #0F6F73)

---

## 📱 Required Images for Each Screen

### **1. Phone Verification Input Screen**

**File Name**: `phone_verification.png`

**Freepik Search Terms**:
- "person holding phone illustration flat"
- "mobile phone verification illustration"
- "smartphone user illustration vector"
- "phone authentication flat design"
- "person texting illustration modern"

**Description**: 
Illustration of a person holding a smartphone, looking at the screen. Should convey the action of entering a phone number or receiving a message. Friendly, approachable style with warm colors.

**Alternative Icons** (if illustration not available):
- Material Icon: `Icons.phone_android_rounded`
- Color: #1FBF9A

---

### **2. Phone OTP Verification Screen**

**File Name**: `phone_otp.png`

**Freepik Search Terms**:
- "sms verification code illustration"
- "otp verification illustration flat"
- "person receiving text message illustration"
- "mobile security code illustration"
- "phone verification code vector"

**Description**: 
Illustration showing a person looking at their phone with a verification code or SMS message visible. Should emphasize the concept of receiving and entering a code.

**Alternative Icons** (if illustration not available):
- Material Icon: `Icons.sms_rounded`
- Color: #1FBF9A

---

### **3. Email Verification Screen**

**File Name**: `email_verification.png`

**Freepik Search Terms**:
- "email verification illustration flat"
- "person checking email illustration"
- "mail inbox illustration vector"
- "email notification illustration modern"
- "email security illustration"

**Description**: 
Illustration of a person checking their email on a device (laptop or phone), with an envelope or email icon. Should convey the action of receiving and verifying an email.

**Alternative Icons** (if illustration not available):
- Material Icon: `Icons.email_rounded`
- Color: #1FBF9A

---

## 🎨 Recommended Freepik Collections

### **Best Collections to Browse:**

1. **Storyset by Freepik**
   - URL: https://storyset.com/
   - Category: "Technology" or "People"
   - Style: Customizable colors, modern flat design
   - Perfect for: All verification screens

2. **Freepik Flat Illustrations**
   - Search: "mobile verification flat illustration"
   - Filter: Vector, Free/Premium
   - Style: Clean, minimal, professional

3. **Undraw Illustrations**
   - URL: https://undraw.co/
   - Free, customizable color
   - Search: "authentication", "mobile", "email"

---

## 📐 Image Preparation Steps

### **After Downloading from Freepik:**

1. **Open in Design Tool** (Figma, Photoshop, or Illustrator)
2. **Resize to 400x400px**
3. **Center the illustration** within the canvas
4. **Adjust colors** to match OmniCare brand:
   - Primary: #1FBF9A (Seafoam Green)
   - Secondary: #0F6F73 (Deep Teal)
   - Accent: #6BE3B2 (Soft Mint)
5. **Export as PNG** with transparent background
6. **Optimize file size** (should be < 100KB)

---

## 🔧 Alternative: Using Custom Icons (Temporary)

If you can't find suitable illustrations immediately, the screens will fall back to Material Icons:

- **Phone Input**: `Icons.phone_android_rounded`
- **Phone OTP**: `Icons.sms_rounded`
- **Email Verification**: `Icons.email_rounded`

These are already implemented in the code and will display in the brand color (#1FBF9A).

---

## 📝 Implementation Notes

### **Current Code References:**

**Phone Input Screen** (`phone_input_screen.dart` line 92-104):
```dart
Image.asset(
  'assets/images/phone_verification.png',
  width: 140,
  height: 140,
  fit: BoxFit.contain,
  errorBuilder: (context, error, stackTrace) {
    return Icon(
      Icons.phone_android_rounded,
      size: 80,
      color: const Color(0xFF1FBF9A),
    );
  },
)
```

**OTP Verification Screen** (`otp_verification_screen.dart` line 144-158):
```dart
Image.asset(
  isEmail 
    ? 'assets/images/email_verification.png'
    : 'assets/images/phone_otp.png',
  width: 140,
  height: 140,
  fit: BoxFit.contain,
  errorBuilder: (context, error, stackTrace) {
    return Icon(
      isEmail ? Icons.email_rounded : Icons.sms_rounded,
      size: 80,
      color: const Color(0xFF1FBF9A),
    );
  },
)
```

---

## ✅ Checklist

- [ ] Create `assets/images/` folder
- [ ] Download `phone_verification.png` from Freepik
- [ ] Download `phone_otp.png` from Freepik
- [ ] Download `email_verification.png` from Freepik
- [ ] Resize all images to 400x400px
- [ ] Adjust colors to match OmniCare brand
- [ ] Export as PNG with transparent background
- [ ] Place all images in `assets/images/` folder
- [ ] Update `pubspec.yaml` to include assets (if not already done)
- [ ] Run `flutter pub get`
- [ ] Test on simulator/device

---

## 📦 Update pubspec.yaml

Make sure your `pubspec.yaml` includes:

```yaml
flutter:
  assets:
    - assets/images/
```

Then run:
```bash
flutter pub get
```

---

**Last Updated**: February 28, 2026
**Maintained By**: OmniCare Mobile Development Team
