-- ═══════════════════════════════════════════════════════════════
--  تحصين الصلاحيات — المرحلة الأولى
--
--  المشكلة اللي يحلها هذا الملف:
--  السياسات القديمة مكتوبة `to authenticated using (true)` — يعني أي حساب
--  مسجّل عنده صلاحية كاملة (إضافة/تعديل/حذف كلشي). الحماية كلها معتمدة على
--  إن التسجيل الذاتي مطفي باللوحة. هنا نثبّتها على حسابج أنتِ بدل ذاك.
--
--  شلون تنفّذينه:
--    Supabase → SQL Editor → الصقي الملف كامل → Run
--  آمن تنفّذينه أكثر من مرة، وما يلمس أي بيانات موجودة.
--
--  ⚠️  بالخطوة ② بيه حاجز أمان: إذا ما انلگى أي حساب، السكربت يوقف نفسه
--      بدل ما يقفل اللوحة بوجهج.
-- ═══════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════
--  ①  جدول المشرفات + دالة الفحص
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  note       text default '',
  created_at timestamptz not null default now()
);

-- ماكو سياسات على الجدول = ماكو أحد يقرا منه مباشرة.
-- الدالة تحت `security definer` فتشوفه رغم ذلك.
alter table public.admins enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;


-- ═══════════════════════════════════════════════════════════════
--  ②  تسجيل حسابج + حاجز الأمان
-- ═══════════════════════════════════════════════════════════════

-- شوفي أول شنو الحسابات الموجودة:
--     select id, email, created_at from auth.users order by created_at;
--
-- السطر الجاي ياخذ كل الحسابات الموجودة حالياً. إذا عندج حساب وحيد (وهذا
-- المفروض يكون الوضع) فهو الصح. إذا طلعت حسابات ما تعرفينها، احذفي الصف
-- الزايد بعدين:  delete from public.admins where user_id = '<id>';

insert into public.admins (user_id, note)
select id, coalesce(email, '') from auth.users
on conflict (user_id) do nothing;

-- الحاجز: لا تكمل إذا الجدول فاضي — وإلا تنقفل اللوحة بوجهج ولا تكدرين
-- تعدّلين ولا تحذفين أي شي.
do $$
begin
  if not exists (select 1 from public.admins) then
    raise exception
      'توقف: جدول admins فاضي. سوّي حساب من Authentication → Users، وبعدين شغّلي الملف مرة ثانية.';
  end if;
end $$;


-- ═══════════════════════════════════════════════════════════════
--  ③  سياسات الجداول — بدل "أي مسجّل" صارت "المشرفة فقط"
-- ═══════════════════════════════════════════════════════════════

drop policy if exists recipes_public_read   on public.recipes;
drop policy if exists recipes_admin_all     on public.recipes;
drop policy if exists courses_public_read   on public.courses;
drop policy if exists courses_admin_all     on public.courses;
drop policy if exists site_info_public_read on public.site_info;
drop policy if exists site_info_admin_all   on public.site_info;

-- الزوار يشوفون المنشور فقط، والمشرفة تشوف كلشي (حتى المخفي)
create policy recipes_public_read on public.recipes
  for select to anon, authenticated
  using (is_published = true or public.is_admin());

create policy recipes_admin_all on public.recipes
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy courses_public_read on public.courses
  for select to anon, authenticated
  using (is_published = true or public.is_admin());

create policy courses_admin_all on public.courses
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy site_info_public_read on public.site_info
  for select to anon, authenticated using (true);

create policy site_info_admin_all on public.site_info
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());


-- ═══════════════════════════════════════════════════════════════
--  ④  بكت الصور — قيود على النوع والحجم والمجلد
--
--  فحص المتصفح بـ admin.html ينلتف عليه بطلب مباشر للـ API،
--  فالقيود الحقيقية لازم تكون هنا.
-- ═══════════════════════════════════════════════════════════════

update storage.buckets
set file_size_limit    = 5242880,                                   -- ٥ ميغا
    allowed_mime_types = array['image/jpeg','image/png','image/webp']
where id = 'media';

drop policy if exists media_public_read  on storage.objects;
drop policy if exists media_admin_insert on storage.objects;
drop policy if exists media_admin_update on storage.objects;
drop policy if exists media_admin_delete on storage.objects;

-- القراءة للجميع (البكت عام والصور تنعرض بالموقع)
create policy media_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'media');

-- الرفع للمشرفة فقط، وبالمجلدات الأربعة المعروفة حصراً
create policy media_admin_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and public.is_admin()
    and (storage.foldername(name))[1] in ('recipes','courses','site','avatar')
  );

create policy media_admin_update on storage.objects
  for update to authenticated
  using  (bucket_id = 'media' and public.is_admin())
  with check (
    bucket_id = 'media'
    and public.is_admin()
    and (storage.foldername(name))[1] in ('recipes','courses','site','avatar')
  );

create policy media_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and public.is_admin());


-- ═══════════════════════════════════════════════════════════════
--  ⑤  التحقق — شغّلي هذولا وشوفي النتيجة
-- ═══════════════════════════════════════════════════════════════

-- المفروض ترجع صف واحد بإيميلج:
select a.user_id, u.email
from public.admins a join auth.users u on u.id = a.user_id;

-- المفروض كل السياسات تذكر is_admin() ما عدا القراءة العامة:
select tablename, policyname, cmd
from pg_policies
where schemaname in ('public','storage')
  and tablename in ('recipes','courses','site_info','objects')
order by tablename, policyname;

-- المفروض تبين حدود البكت:
select id, public, file_size_limit, allowed_mime_types
from storage.buckets where id = 'media';
