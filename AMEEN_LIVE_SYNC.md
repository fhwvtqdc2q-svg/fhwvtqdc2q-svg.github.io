# مزامنة الأمين اللحظية

الهدف: لا نرفع ملف جرد يومي يدويا. بدلا من ذلك يعمل وكيل صغير على جهاز Windows بجانب برنامج الأمين، يقرأ قاعدة SQL Server قراءة فقط، ثم يرسل ملخص المخزون إلى Supabase كل دقيقة. بعدها يظهر الملخص والتنبيهات على iPhone من صفحة `الأمين`.

## ما تم تجهيزه

- `tools/ameen-sync-agent.ps1`: وكيل مزامنة Windows.
- `tools/discover-ameen-sql.ps1`: فحص اتصال SQL Server وعرض قواعد البيانات.
- `tools/ameen-stock-query.sql`: مكان الاستعلام الذي سنضع فيه جداول الأمين الحقيقية بعد اكتشافها.
- الواجهة جاهزة لقراءة آخر التقارير من جدول `inventory_reports`.

## لماذا لا يقرأ iPhone الأمين مباشرة؟

قاعدة الأمين محلية داخل Windows/SQL Server. الهاتف لا يصل إليها بأمان مباشرة، ولا يجب فتح SQL Server على الإنترنت. لذلك يكون الاتصال الصحيح:

```text
Al-Ameen SQL Server on Windows -> Ameen Sync Agent -> Supabase -> iPhone/Web
```

## المطلوب مرة واحدة فقط

نحتاج معرفة:

- اسم قاعدة بيانات الأمين داخل SQL Server.
- أسماء جداول المواد والفواتير أو الاستعلام الذي يعطينا `اسم المادة` و`الكمية`.
- مستخدم SQL بصلاحية قراءة فقط.

## إعداد متغيرات البيئة

بعد إنشاء مستخدم قراءة فقط في SQL Server ومستخدم مزامنة في Supabase، ضع القيم على Windows:

```powershell
[Environment]::SetEnvironmentVariable("AMEEN_SQL_CONNECTION_STRING", "Server=localhost;Database=AMEEN_DATABASE_NAME;User ID=tobacco_sync_reader;Password=PUT_PASSWORD_HERE;TrustServerCertificate=True;", "User")
[Environment]::SetEnvironmentVariable("TOBACCO_SUPABASE_URL", "https://dyxbirfpxeocqffnfdeb.supabase.co", "User")
[Environment]::SetEnvironmentVariable("TOBACCO_SUPABASE_PUBLIC_KEY", "PUT_PUBLIC_KEY_HERE", "User")
[Environment]::SetEnvironmentVariable("TOBACCO_SYNC_EMAIL", "PUT_SYNC_USER_EMAIL_HERE", "User")
[Environment]::SetEnvironmentVariable("TOBACCO_SYNC_PASSWORD", "PUT_SYNC_USER_PASSWORD_HERE", "User")
```

لا تضع كلمة مرور SQL أو كلمة مرور Supabase داخل GitHub أو داخل ملفات المشروع.

## تشغيل اختبار واحد

```powershell
cd "C:\Users\DELL\Documents\New project\web-platform"
.\tools\ameen-sync-agent.ps1 -Once -LowThreshold 50
```

إذا نجح الاختبار سيظهر تقرير جديد داخل صفحة `الأمين`.

## تشغيل دائم كل دقيقة

```powershell
cd "C:\Users\DELL\Documents\New project\web-platform"
.\tools\ameen-sync-agent.ps1 -IntervalSeconds 60 -LowThreshold 50
```

لاحقا يمكن تحويله إلى Windows Scheduled Task أو خدمة Windows ليعمل تلقائيا عند تشغيل اللابتوب.

## حدود مهمة

- الوكيل يقرأ من الأمين فقط ولا يكتب داخل قاعدة الأمين.
- لا نستخدم `service_role` في الواجهة.
- لا نفتح SQL Server على الإنترنت.
- حتى نصل للربط الحقيقي يجب تعديل `tools/ameen-stock-query.sql` حسب أسماء جداول قاعدة الأمين.
