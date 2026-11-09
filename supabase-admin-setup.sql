-- راه‌اندازی امن پنل مدیریت سایت خادم‌الشهداء بهبهان
-- این فایل را در Supabase > SQL Editor اجرا کنید.
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$;
revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to authenticated;

drop policy if exists "Admins can read admin list" on public.admin_users;
create policy "Admins can read admin list" on public.admin_users
for select to authenticated using (public.is_site_admin());

create table if not exists public.site_content (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('news','event','shohada','gallery')),
  title text not null,
  body text not null,
  event_date text,
  location text,
  organizer text,
  image_url text,
  published boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.site_content enable row level security;
drop policy if exists "Public can read published content" on public.site_content;
create policy "Public can read published content" on public.site_content
for select to anon, authenticated using (published = true);
drop policy if exists "Admins can read all content" on public.site_content;
create policy "Admins can read all content" on public.site_content
for select to authenticated using (public.is_site_admin());
drop policy if exists "Admins can insert content" on public.site_content;
create policy "Admins can insert content" on public.site_content
for insert to authenticated with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
drop policy if exists "Admins can update content" on public.site_content;
create policy "Admins can update content" on public.site_content
for update to authenticated using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
drop policy if exists "Admins can delete content" on public.site_content;
create policy "Admins can delete content" on public.site_content
for delete to authenticated using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

-- دسترسی مدیر برای خواندن پیام‌های مردمی (اگر جدول فعلی وجود داشته باشد)
do $$
begin
  if to_regclass('public.feedback_messages') is not null then
    execute 'alter table public.feedback_messages enable row level security';
    execute 'drop policy if exists "Admins can read feedback" on public.feedback_messages';
    execute 'create policy "Admins can read feedback" on public.feedback_messages for select to authenticated using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))';
  end if;
end $$;

-- پس از ساخت حساب مدیر در Authentication > Users، شناسه UUID او را جایگزین کنید:
-- insert into public.admin_users (user_id) values ('UUID-کاربر-مدیر');

-- مدیریت بنرهای صفحه اصلی
create table if not exists public.site_banners (
 id uuid primary key default gen_random_uuid(),
 title text not null,
 image_url text not null,
 target_url text,
 active boolean not null default true,
 sort_order integer not null default 0,
 created_at timestamptz not null default now()
);
alter table public.site_banners enable row level security;
drop policy if exists "Public can read active banners" on public.site_banners;
create policy "Public can read active banners" on public.site_banners
 for select to anon, authenticated using (active = true);
drop policy if exists "Admins can read all banners" on public.site_banners;
create policy "Admins can read all banners" on public.site_banners
 for select to authenticated using (public.is_site_admin());
drop policy if exists "Admins can insert banners" on public.site_banners;
create policy "Admins can insert banners" on public.site_banners
 for insert to authenticated with check (public.is_site_admin());
drop policy if exists "Admins can update banners" on public.site_banners;
create policy "Admins can update banners" on public.site_banners
 for update to authenticated using (public.is_site_admin()) with check (public.is_site_admin());
drop policy if exists "Admins can delete banners" on public.site_banners;
create policy "Admins can delete banners" on public.site_banners
 for delete to authenticated using (public.is_site_admin());

-- Storage bucket for site images and banners
insert into storage.buckets (id,name,public)
values ('site-images','site-images',true)
on conflict (id) do update set public = true;
drop policy if exists "Public can view site images" on storage.objects;
create policy "Public can view site images" on storage.objects
for select to anon, authenticated using (bucket_id = 'site-images');
drop policy if exists "Admins can upload site images" on storage.objects;
create policy "Admins can upload site images" on storage.objects
for insert to authenticated with check (bucket_id = 'site-images' and public.is_site_admin());
drop policy if exists "Admins can update site images" on storage.objects;
create policy "Admins can update site images" on storage.objects
for update to authenticated using (bucket_id = 'site-images' and public.is_site_admin())
with check (bucket_id = 'site-images' and public.is_site_admin());
drop policy if exists "Admins can delete site images" on storage.objects;
create policy "Admins can delete site images" on storage.objects
for delete to authenticated using (bucket_id = 'site-images' and public.is_site_admin());

-- عنوان بنر اختیاری است
alter table public.site_banners alter column title drop not null;
