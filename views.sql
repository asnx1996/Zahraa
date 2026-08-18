-- ══════════════════════════════════════════════════════════
--  عدّاد المشاهدات
--  آمن يتكرر — نفّذيه كل ما تريدين بدون خوف
-- ══════════════════════════════════════════════════════════
--
--  ليش جدول منفصل مو عمود بـ recipes؟
--  لأن أي update على recipes يشغّل ترايكر touch_updated_at ويغيّر
--  updated_at — يعني كل فتحة وصفة تخلي الوصفة تبين «معدّلة اليوم».
--  وبعدين anon ما عنده صلاحية update على recipes أصلاً، ولا نريد
--  ننطيه إياها.
--
--  الزيادة تمر بدالة security definer وحدة: الزائرة تنادي الدالة،
--  والدالة تكتب. ماكو صلاحية كتابة مباشرة على الجدول لأي أحد.

-- ── الجدول ──
create table if not exists public.item_views (
  kind       text        not null check (kind in ('recipes','courses')),
  item_id    uuid        not null,
  views      bigint      not null default 0,
  last_view  timestamptz not null default now(),
  primary key (kind, item_id)
);

alter table public.item_views enable row level security;

-- ── الصلاحيات ──
-- القراءة للمشرفة فقط: أرقام المشاهدات معلومة داخلية، والزائرة
-- ما تحتاجها ولا نريد نكشف أي وصفة «ميتة».
drop policy if exists item_views_read on public.item_views;
create policy item_views_read on public.item_views
  for select using (public.is_admin());

-- ماكو سياسة insert/update/delete إطلاقاً — يعني ولا أحد يكتب
-- بشكل مباشر، لا anon ولا حتى المشرفة. الكتابة كلها من الدالة تحت.
-- (المشرفة تكدر تحذف الصفوف عبر cascade مال حذف العنصر، شوف الترايكر.)

-- ── الزيادة ──
create or replace function public.bump_view(p_kind text, p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind not in ('recipes','courses') then
    return;                         -- مدخل غريب = ما نسوي شي، بدون خطأ
  end if;

  -- ما نزيد إلا إذا العنصر موجود ومنشور فعلاً — بدونها أي واحد
  -- يكدر ينفخ صفوف بمعرّفات وهمية ويكبّر الجدول بلا فايدة.
  if p_kind = 'recipes' then
    if not exists (select 1 from public.recipes where id = p_id and is_published) then return; end if;
  else
    if not exists (select 1 from public.courses where id = p_id and is_published) then return; end if;
  end if;

  insert into public.item_views (kind, item_id, views)
  values (p_kind, p_id, 1)
  on conflict (kind, item_id) do update
    set views = public.item_views.views + 1,
        last_view = now();
end;
$$;

revoke all on function public.bump_view(text, uuid) from public;
grant execute on function public.bump_view(text, uuid) to anon, authenticated;

-- ── تنظيف بعد الحذف ──
-- الجدول ما بيه foreign key (لأنه يخدم جدولين)، فالصف يبقى يتيم لو
-- انحذفت الوصفة. الترايكر هذا ينظّفه.
create or replace function public.drop_item_views()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.item_views
   where item_id = old.id
     and kind = tg_argv[0];
  return old;
end;
$$;

drop trigger if exists t_recipes_views_cleanup on public.recipes;
drop trigger if exists t_courses_views_cleanup on public.courses;

create trigger t_recipes_views_cleanup after delete on public.recipes
  for each row execute function public.drop_item_views('recipes');
create trigger t_courses_views_cleanup after delete on public.courses
  for each row execute function public.drop_item_views('courses');

-- ══════════════════════════════════════════════════════════
--  ملاحظة صريحة عن الدقة
--  ══════════════════════════════════════════════════════════
--  الرقم هذا «كم مرة انفتحت التفاصيل»، مو عدد أشخاص. الموقع يمنع
--  التكرار داخل نفس الجلسة (sessionStorage) بس ماكو منع حقيقي من
--  السيرفر: أي واحد يعرف يستعمل الأدوات يكدر ينادي الدالة بالتكرار.
--  للمقارنة بين الوصفات («أي وحدة تمشي أكثر») الرقم يكفي ويزيد.
--  إذا انراد رقم يُعتمد عليه بالإعلان أو التقارير، لازم تحديد معدّل
--  على مستوى السيرفر (Edge Function + IP) — ومو موجود هسه.
