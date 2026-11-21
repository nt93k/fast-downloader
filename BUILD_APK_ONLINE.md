# بناء APK بدون Android Studio (عبر GitHub Actions)

جهّزنا ملف `.github/workflows/build-apk.yml` اللي يبني التطبيق في السحابة ويعطيك ملف APK جاهز.

## الخطوات

1. أنشئ حساب في [GitHub](https://github.com) إذا ما عندك.

2. افتح Terminal داخل المشروع وحوّله إلى مستودع git:
   ```bash
   cd "/home/abbas/Documents/Default Project/code/fast_downloader"
   git init
   git add .
   git commit -m "Fast downloader app"
   ```

3. أنشئ مستودع جديد فارغ في GitHub (من زر **New repository**)، ثم اربطه وادفع الكود:
   ```bash
   git remote add origin https://github.com/اسمحسابك/اسمالمستودع.git
   git branch -M main
   git push -u origin main
   ```
   (GitHub يطلب PAT بدل كلمة المرور؛ من `Settings → Developer settings → Personal access tokens`.)

4. افتح المستودع في GitHub → تبويب **Actions** → ستجد `Build Android APK` يشتغل تلقائياً.

5. بعد ما يكمل (حوالي 5–10 دقائق)، اضغط على الـ workflow → من قسم **Artifacts** نزّل `app-release-apk` → استخرج الملف `app-release.apk` وثبّته على جوالك.

## ملاحظات
- الـ Runner في GitHub يثبّت NDK تلقائياً عبر الخطوة الموجودة في الملف، فما تحتاج Android Studio ولا NDK عندك.
- كل تعديل تدفعه (`git push`) يعمل APK جديد تلقائياً.
- بديل جاهز أكثر: [Codemagic](https://codemagic.io) — اربط مستودعك واختار Flutter workflow، ومنه تحمل الـ APK مباشرة.
