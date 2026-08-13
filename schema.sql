-- ═══════════════════════════════════════════════════════════════
--  موقع كوتش زهراء — سكيما قاعدة البيانات
--  نفّذ هذا الملف كامل مرة واحدة بـ Supabase → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

-- ═══════════════════════════════════════════════════════════════
--  ①  الجداول
-- ═══════════════════════════════════════════════════════════════

-- معلومات الحساب ومحتوى الصفحة الرئيسية (صف واحد فقط)
create table if not exists public.site_info (
  id          int primary key default 1,
  name        text not null default 'كوتش زهراء',
  initial     text not null default 'ز',
  tagline     text default '',
  bio         text default '',
  avatar_url  text default '',
  instagram   text default '',
  whatsapp    text default '',
  updated_at  timestamptz not null default now(),
  constraint  single_row check (id = 1)
);

-- محتوى الصفحة الرئيسية القابل للتعديل من اللوحة (ثنائي اللغة)
-- كل حقل نصّي مخزون كـ {"ar":"…","en":"…"}
alter table public.site_info
  add column if not exists name_en      text  not null default '',
  add column if not exists tagline_en   text  not null default '',
  add column if not exists bio_en       text  not null default '',
  add column if not exists hero_eyebrow jsonb not null default '{"ar":"","en":""}'::jsonb,
  add column if not exists hero_title   jsonb not null default '{"ar":"","en":""}'::jsonb,
  add column if not exists hero_sub     jsonb not null default '{"ar":"","en":""}'::jsonb,
  add column if not exists hero_image   text  not null default '',
  add column if not exists about_image  text  not null default '',
  add column if not exists stats        jsonb not null default '[]'::jsonb,
  add column if not exists creds        jsonb not null default '[]'::jsonb,
  add column if not exists plans        jsonb not null default '[]'::jsonb,
  add column if not exists quotes       jsonb not null default '[]'::jsonb,
  add column if not exists faq          jsonb not null default '[]'::jsonb,
  add column if not exists credit       jsonb not null default '{"ar":"","en":""}'::jsonb;

-- شكل الحقول:
--   stats  : [{"n":{"ar":"+٢٥٠","en":"250+"},"l":{"ar":"مشتركة","en":"members"}}]
--   creds  : [{"icon":"i-shield","t":{"ar":"…","en":"…"},"s":{"ar":"…","en":"…"}}]
--   plans  : [{"featured":true,"name":{…},"tag":{…},"price":{…},"unit":{…},"desc":{…},
--              "features":{"ar":["…"],"en":["…"]}}]
--   quotes : [{"t":{…},"n":{…},"r":{…}}]
--   faq    : [{"q":{…},"a":{…}}]

-- الوصفات
create table if not exists public.recipes (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  cover        text default '',
  tag          text not null default 'غداء',        -- فطور / غداء / عشاء / سناك
  duration     text default '',                     -- "25 دقيقة"
  servings     int  not null default 1 check (servings > 0),
  kcal         int  not null default 0 check (kcal    >= 0),
  protein      numeric(6,1) not null default 0 check (protein >= 0),
  carbs        numeric(6,1) not null default 0 check (carbs   >= 0),
  fat          numeric(6,1) not null default 0 check (fat     >= 0),
  video        text default '',
  ingredients  jsonb not null default '[]'::jsonb,  -- [{"q":300,"u":"غم","n":"صدر دجاج"}]
  steps        jsonb not null default '[]'::jsonb,  -- ["الخطوة الأولى", "..."]
  is_published boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- الكورسات
create table if not exists public.courses (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  cover        text default '',
  tag          text not null default 'مبتدئ',       -- مبتدئ / متوسط / متقدم
  area         text default '',                     -- بطن وكور / جسم كامل / كارديو
  duration     text default '',
  video        text default '',
  description  text default '',
  moves        jsonb not null default '[]'::jsonb,  -- [{"n":"بلانك","s":"3 × 40 ثانية"}]
  is_published boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists recipes_order_idx on public.recipes (sort_order, created_at desc);
create index if not exists courses_order_idx on public.courses (sort_order, created_at desc);
create index if not exists recipes_tag_idx   on public.recipes (tag);
create index if not exists courses_tag_idx   on public.courses (tag);

-- ═══════════════════════════════════════════════════════════════
--  ②  تحديث updated_at تلقائياً
-- ═══════════════════════════════════════════════════════════════

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists t_recipes_touch   on public.recipes;
drop trigger if exists t_courses_touch   on public.courses;
drop trigger if exists t_site_info_touch on public.site_info;

create trigger t_recipes_touch   before update on public.recipes   for each row execute function public.touch_updated_at();
create trigger t_courses_touch   before update on public.courses   for each row execute function public.touch_updated_at();
create trigger t_site_info_touch before update on public.site_info for each row execute function public.touch_updated_at();

-- ═══════════════════════════════════════════════════════════════
--  ③  الصلاحيات (RLS)
--     الزوار: قراءة المنشور فقط
--     المسجّل دخوله (زهراء): كل شي
-- ═══════════════════════════════════════════════════════════════

alter table public.recipes   enable row level security;
alter table public.courses   enable row level security;
alter table public.site_info enable row level security;

drop policy if exists recipes_public_read   on public.recipes;
drop policy if exists recipes_admin_all     on public.recipes;
drop policy if exists courses_public_read   on public.courses;
drop policy if exists courses_admin_all     on public.courses;
drop policy if exists site_info_public_read on public.site_info;
drop policy if exists site_info_admin_all   on public.site_info;

create policy recipes_public_read on public.recipes
  for select to anon, authenticated using (is_published = true or auth.role() = 'authenticated');

create policy recipes_admin_all on public.recipes
  for all to authenticated using (true) with check (true);

create policy courses_public_read on public.courses
  for select to anon, authenticated using (is_published = true or auth.role() = 'authenticated');

create policy courses_admin_all on public.courses
  for all to authenticated using (true) with check (true);

create policy site_info_public_read on public.site_info
  for select to anon, authenticated using (true);

create policy site_info_admin_all on public.site_info
  for all to authenticated using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════
--  ④  تخزين الصور
-- ═══════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

drop policy if exists media_public_read  on storage.objects;
drop policy if exists media_admin_insert on storage.objects;
drop policy if exists media_admin_update on storage.objects;
drop policy if exists media_admin_delete on storage.objects;

create policy media_public_read on storage.objects
  for select to anon, authenticated using (bucket_id = 'media');

create policy media_admin_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'media');

create policy media_admin_update on storage.objects
  for update to authenticated using (bucket_id = 'media');

create policy media_admin_delete on storage.objects
  for delete to authenticated using (bucket_id = 'media');

-- ═══════════════════════════════════════════════════════════════
--  ⑤  البيانات الحالية (نفس محتوى الديمو)
-- ═══════════════════════════════════════════════════════════════

insert into public.site_info (id, name, initial, tagline, bio, instagram, whatsapp)
values (1, 'كوتش زهراء', 'ز',
  'تمارين ووصفات — كلشي محسوب بالسعرات',
  'مدربة لياقة وتغذية. كل برنامج هنا مبني على أهداف واقعية وأكل تكدرين تسوينه بمطبخج، بدون حرمان وبدون منتجات غالية.',
  'https://instagram.com/', 'https://wa.me/9647700000000')
on conflict (id) do nothing;

insert into public.recipes (title, cover, tag, duration, servings, kcal, protein, carbs, fat, video, ingredients, steps, sort_order) values
('دجاج مشوي مع رز وسلطة',
 'https://images.unsplash.com/photo-1781334266250-a7e72fdf539f?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'غداء', '30 دقيقة', 2, 540, 46, 55, 13, 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
 '[{"q":300,"u":"غم","n":"صدر دجاج"},{"q":160,"u":"غم","n":"رز (وزن ناشف)"},{"q":1,"u":"معلقة","n":"زيت زيتون"},{"q":2,"u":"حبة","n":"طماطة"},{"q":1,"u":"حبة","n":"خيار"},{"q":0.5,"u":"معلقة صغيرة","n":"بابريكا"},{"q":1,"u":"رشة","n":"ملح وفلفل أسود"}]',
 '["تبّل الدجاج بالزيت والبابريكا والملح وخلّيه ١٠ دقائق.","اطبخ الرز على نار هادئة لحد ما ينضج.","اشوِ الدجاج ٦ دقائق لكل جهة على نار متوسطة.","قطّع الطماطة والخيار وقدّمهم سلطة جنب الصحن."]', 1),

('بول بروتين باللحم والخضار',
 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'غداء', '25 دقيقة', 2, 610, 42, 48, 22, '',
 '[{"q":300,"u":"غم","n":"لحم قليل الدهن مقطّع"},{"q":150,"u":"غم","n":"كينوا أو رز"},{"q":1,"u":"حبة","n":"أفوكادو"},{"q":100,"u":"غم","n":"ذرة حلوة"},{"q":1,"u":"معلقة","n":"زيت زيتون"},{"q":1,"u":"معلقة","n":"عصير ليمون"}]',
 '["اقلي اللحم بمقلاة حارة مع رشة ملح ٧ دقائق.","اسلق الكينوا وصفّيها.","رتّب البول: كينوا بالقاع، وبعدين اللحم والخضار.","رش الزيت والليمون فوق قبل التقديم."]', 2),

('بيض بوشيه مع خضار',
 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'فطور', '12 دقيقة', 1, 330, 22, 18, 19, '',
 '[{"q":2,"u":"حبة","n":"بيض"},{"q":100,"u":"غم","n":"طماطة كرزية"},{"q":50,"u":"غم","n":"جرجير"},{"q":1,"u":"معلقة صغيرة","n":"زيت زيتون"},{"q":1,"u":"رشة","n":"ملح وفلفل"}]',
 '["غلي الماي وحط معلقة خل، وسوّي دوامة وكسّر البيضة بيها.","اتركها ٣ دقائق وطلّعها بمصفاة.","رتّب الجرجير والطماطة بالصحن وحط البيض فوق.","رش الزيت والملح والفلفل."]', 3),

('ساندويچ صحي بالبيض المسلوق',
 'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'فطور', '10 دقائق', 1, 390, 24, 38, 16, 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
 '[{"q":2,"u":"قطعة","n":"خبز أسمر"},{"q":2,"u":"حبة","n":"بيض مسلوق"},{"q":0.5,"u":"حبة","n":"أفوكادو"},{"q":30,"u":"غم","n":"خس"},{"q":1,"u":"رشة","n":"ملح وفلفل"}]',
 '["حمّص الخبز بالتوستر أو المقلاة بدون زيت.","اهرس الأفوكادو وافرده على الخبز.","قطّع البيض شرائح وحطه فوق مع الخس.","رشة ملح وفلفل وجاهز."]', 4),

('سلطة تونة عالية البروتين',
 'https://images.unsplash.com/photo-1505253716362-afaea1d3d1af?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'سناك', '10 دقائق', 2, 290, 32, 14, 11, '',
 '[{"q":2,"u":"علبة","n":"تونة بالماي"},{"q":100,"u":"غم","n":"خس"},{"q":1,"u":"حبة","n":"خيار"},{"q":2,"u":"حبة","n":"طماطة"},{"q":2,"u":"معلقة","n":"لبن يوناني"},{"q":1,"u":"معلقة","n":"عصير ليمون"}]',
 '["صفّي التونة زين من الماي.","قطّع الخضار وخلّطهم بالسلطانية.","اخلط اللبن مع الليمون وصبّه فوق وقلّب."]', 5),

('سلطة فواكه مع لبن يوناني',
 'https://images.unsplash.com/photo-1493770348161-369560ae357d?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'سناك', '7 دقائق', 2, 245, 16, 34, 5, '',
 '[{"q":250,"u":"غم","n":"لبن يوناني"},{"q":1,"u":"حبة","n":"موز"},{"q":100,"u":"غم","n":"فراولة"},{"q":1,"u":"معلقة","n":"عسل"},{"q":10,"u":"غم","n":"جوز مفروم"}]',
 '["قطّع الفواكه مكعبات صغيرة.","وزّع اللبن بالسلطانيات وحط الفواكه فوق.","رش العسل والجوز قبل التقديم."]', 6),

('صحن خضار وحبوب متوازن',
 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'عشاء', '20 دقيقة', 2, 420, 19, 52, 15, '',
 '[{"q":150,"u":"غم","n":"حمص مسلوق"},{"q":120,"u":"غم","n":"برغل"},{"q":100,"u":"غم","n":"ملفوف أحمر"},{"q":1,"u":"حبة","n":"جزر"},{"q":2,"u":"معلقة","n":"طحينة"},{"q":1,"u":"معلقة","n":"عصير ليمون"}]',
 '["اسلق البرغل وخلّيه يبرد شوية.","ابشر الجزر وقطّع الملفوف ناعم.","اخلط الطحينة مع الليمون وشوية ماي حتى تصير صوص.","رتّب كلشي بالصحن وصبّ الصوص فوق."]', 7),

('بول رز مع خضار سوتيه',
 'https://images.unsplash.com/photo-1606756790138-261d2b21cd75?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'عشاء', '22 دقيقة', 2, 465, 28, 60, 12, '',
 '[{"q":160,"u":"غم","n":"رز (وزن ناشف)"},{"q":200,"u":"غم","n":"دجاج مقطّع"},{"q":150,"u":"غم","n":"بروكلي"},{"q":1,"u":"حبة","n":"فلفل حلو"},{"q":1,"u":"معلقة","n":"صويا صوص"},{"q":1,"u":"معلقة صغيرة","n":"زيت سمسم"}]',
 '["اطبخ الرز وخلّه جانباً.","اقلي الدجاج بنار عالية ٥ دقائق.","ضيف الخضار وقلّب ٣ دقائق حتى تبقى مقرمشة.","ضيف الصويا وزيت السمسم وقدّمه فوق الرز."]', 8);

insert into public.courses (title, cover, tag, area, duration, video, description, moves, sort_order) values
('تمارين البطن — ١٤ يوم',
 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'مبتدئ', 'بطن وكور', '15 دقيقة/يوم', 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
 'برنامج بيتي بدون أجهزة، ٤ أيام بالأسبوع. يركّز على تقوية عضلات الكور قبل ما ننتقل لتمارين أصعب.',
 '[{"n":"بلانك","s":"3 × 40 ثانية"},{"n":"كرنش","s":"3 × 20 عدة"},{"n":"ليغ رِيز","s":"3 × 15 عدة"},{"n":"ماونتن كلايمبر","s":"3 × 30 ثانية"},{"n":"بلانك جانبي","s":"2 × 30 ثانية لكل جهة"}]', 1),

('جدول الجسم الكامل بالنادي',
 'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'متوسط', 'جسم كامل', '50 دقيقة', '',
 '٣ حصص بالأسبوع بالنادي، مبني على الحركات المركبة اللي تعطي أفضل نتيجة بأقل وقت.',
 '[{"n":"سكوات","s":"4 × 10 عدات"},{"n":"ديدليفت","s":"4 × 8 عدات"},{"n":"بنش برس","s":"3 × 10 عدات"},{"n":"سحب أرضي","s":"3 × 12 عدة"},{"n":"ضغط أكتاف","s":"3 × 12 عدة"}]', 2),

('كارديو حرق دهون HIIT',
 'https://images.unsplash.com/photo-1549576490-b0b4831ef60a?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'متقدم', 'كارديو', '20 دقيقة', 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
 '٨ جولات عالية الشدة — ٤٠ ثانية شغل و٢٠ ثانية راحة. لا تبدين بيه إذا هسه بديتي رياضة.',
 '[{"n":"بيربي","s":"40 ثانية"},{"n":"جامب سكوات","s":"40 ثانية"},{"n":"هاي نيز","s":"40 ثانية"},{"n":"سكيترز","s":"40 ثانية"}]', 3),

('إطالة ومرونة بعد التمرين',
 'https://images.unsplash.com/photo-1518611012118-696072aa579a?fm=jpg&q=70&w=1200&auto=format&fit=crop',
 'مبتدئ', 'مرونة', '12 دقيقة', '',
 'روتين إطالة تسوينه بعد أي تمرين، يقلل شد العضلات ويساعد بالاستشفاء.',
 '[{"n":"إطالة الفخذ الخلفي","s":"2 × 30 ثانية"},{"n":"إطالة الورك","s":"2 × 30 ثانية"},{"n":"وضعية الطفل","s":"60 ثانية"},{"n":"إطالة الصدر والكتف","s":"2 × 20 ثانية"}]', 4);
