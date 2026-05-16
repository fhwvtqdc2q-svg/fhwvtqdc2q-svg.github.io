# TOBACCO Web

منصة خدمة عملاء عربية تعمل من المتصفح على Windows وiPhone وMac، ومتصلة بـ Supabase لحفظ الطلبات.

الرابط العام الحالي:

```text
https://fhwvtqdc2q-svg.github.io/
```

## الحالة الحالية

- تسجيل الدخول يعمل عبر Supabase.
- جدول الطلبات `customer_requests` يعمل.
- الطلبات تحفظ في قاعدة البيانات.
- يمكن تصدير الطلبات بصيغة CSV لفتحها في Excel وتجهيزها للتوافق مع برنامج الأمين.

## التشغيل على Windows

```powershell
cd "C:\Users\DELL\Documents\New project\web-platform"
npm run dev
```

افتح:

```text
http://localhost:5173
```

## الاستخدام على iPhone

افتح الرابط العام من Safari:

```text
https://fhwvtqdc2q-svg.github.io/
```

ثم اختر Share ثم Add to Home Screen.

## التوافق مع Mac وiPhone

هذا المشروع يعمل كتطبيق ويب PWA على Safari. إذا أردنا لاحقا تطبيق iPhone أصلي على App Store، سنحتاج Xcode على Mac أو GitHub Actions macOS runner للبناء والتوقيع.

## التوافق مع الأمين للمحاسبة

الخطوة الحالية هي تصدير الطلبات كملف CSV من صفحة طلبات العملاء. عند توفر قالب الاستيراد من برنامج الأمين، نطابق الأعمدة معه بدقة أو نبني موصل خاص.

## الملفات المهمة

- `src/app.js`: الواجهة والمنطق.
- `src/supabase-client.js`: طبقة Supabase.
- `src/config.js`: إعدادات Supabase العامة.
- `supabase/schema.sql`: جدول الطلبات وسياسات RLS.
- `supabase/permissions-fix.sql`: إصلاح صلاحيات الطلبات عند الحاجة.
- `.github/workflows/pages.yml`: نشر GitHub Pages.

## الفحص

```powershell
npm run check
```
