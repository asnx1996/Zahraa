# موقع كوتش زهراء — سياق المشروع

## نبذة

موقع لمدربة لياقة تنشر عليه **كورسات رياضية** و**وصفات أكل** فيها السعرات
والماكروز والمكونات وطريقة العمل ورابط فيديو. عربي بالكامل، RTL، موبايل أولاً.

## التقنيات (لا تغيّرها)

* **Vanilla HTML/CSS/JS** بملف واحد لكل صفحة — بدون React، بدون build tools، بدون npm
* **الاستضافة:** GitHub Pages → https://asnx1996.github.io/Zahraa/
* **الباك اند:** Supabase (قاعدة بيانات + مصادقة + تخزين صور)
* كل الروابط الداخلية **نسبية** (`admin.html` مو `/Zahraa/admin.html`) لأن الموقع تحت
مجلد فرعي وممكن ينتقل لدومين خاص لاحقاً
* مكتبة Supabase تنجاب من CDN مباشرة (بدون تثبيت)

## Supabase

```
SUPABASE\_URL  = https://kjpwcvhsjfuwzketkjkk.supabase.co
sb\_publishable\_7Sq6BeRa9KQPR1zy1VFHFg\_WOhUoUt0 = <الصق هنا الـ publishable key اللي يبدي بـ sb\_publishable\_...>
```

> الـ publishable key آمن ينحط بالكود العام. الحماية الحقيقية من الـ RLS.
> ⚠️ مفتاح `sb\_secret\_...` ممنوع منعاً باتاً يدخل الكود أو الريبو.

### الجداول

**`recipes`** — id (uuid) · title · cover · tag (فطور/غداء/عشاء/سناك) · duration ·
servings (int) · kcal (int) · protein · carbs · fat (numeric) · video ·
ingredients (jsonb) · steps (jsonb) · is\_published (bool) · sort\_order (int) ·
created\_at · updated\_at

**`courses`** — id (uuid) · title · cover · tag (مبتدئ/متوسط/متقدم) · area ·
duration · video · description · moves (jsonb) · is\_published · sort\_order ·
created\_at · updated\_at

**`site\_info`** — صف واحد فقط (id=1) · name · initial · tagline · bio ·
avatar\_url · instagram · whatsapp

### شكل حقول الـ jsonb

```json
ingredients: \[{"q":300,"u":"غم","n":"صدر دجاج"}]
steps:       \["الخطوة الأولى","الخطوة الثانية"]
moves:       \[{"n":"بلانك","s":"3 × 40 ثانية"}]
```

### الصلاحيات (RLS — مطبّقة أصلاً، لا تعدّلها)

* `anon` → قراءة الصفوف اللي `is\_published = true` فقط
* `authenticated` → كل العمليات (إضافة/تعديل/حذف)
* التسجيل الذاتي **مطفي** — حساب المدربة انسوّى يدوياً من الداشبورد

### تخزين الصور

Bucket عام اسمه **`media`**. الرفع للمسجّل دخوله فقط، القراءة للجميع.
بعد الرفع نخزن الـ public URL بعمود `cover`.

## الملفات

|الملف|الحالة|
|-|-|
|`index.html`|✅ شغّال — بس البيانات لحد الآن مكتوبة يدوياً داخل الكود (مصفوفات `RECIPES` و `COURSES` و `INFO`)|
|`admin.html`|❌ ما انبنى بعد|
|`schema.sql`|✅ انفّذ على Supabase، والبيانات الحالية مزروعة بالجداول|

## المطلوب — بالترتيب

### ١. بناء `admin.html`

* تسجيل دخول بإيميل/باسورد (Supabase Auth) + زر خروج
* إذا مو مسجّل دخول: ما يظهر غير فورم الدخول
* تبويبين: الوصفات / الكورسات + قسم ثالث لتعديل `site\_info`
* جدول يعرض كل العناصر مع أزرار تعديل/حذف/نشر-إخفاء
* فورم إضافة وتعديل يغطي كل الأعمدة، مع:

  * محرر ديناميكي للمكونات (إضافة/حذف سطر: كمية + وحدة + اسم)
  * محرر ديناميكي للخطوات وللتمارين
  * **رفع صورة** لبكت `media` وتعبئة `cover` تلقائياً + معاينة الصورة
* تأكيد قبل الحذف
* نفس هوية التصميم مال `index.html` (نفس متغيرات الـ CSS والخطوط)

### ٢. تحويل `index.html` ليقرا من Supabase

* شيل المصفوفات الثابتة، وجيب البيانات بـ `select` مرتّبة بـ `sort\_order`
* اعرض حالة تحميل (skeleton) وحالة خطأ مفهومة إذا فشل الاتصال
* `site\_info` تتعبى منها الهيدر والبايو ولنكات الانستغرام والواتساب

## هوية التصميم (لا تكسرها)

```
--paper:#E9EEF1  --card:#FFFFFF  --ink:#0F1F29  --soft:#5E717C
--flame:#FF5A3D  --pine:#0E7C66  --amber:#E9A227
خطوط: Reem Kufi (عناوين) · IBM Plex Sans Arabic (نص) · IBM Plex Mono (أرقام)
```

العنصر المميز بالموقع هو **شريط الماكروز** الملوّن (بروتين أخضر / كارب كهرماني /
دهون برتقالي) — يبقى كما هو.

```
```

