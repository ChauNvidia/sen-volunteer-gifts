-- ============================================================
-- SEN Volunteer Gifts: database setup. Run ONCE in Supabase:
--   SQL Editor > New query > paste this whole file > Run.
-- Safe to read: it only creates tables, privacy rules and sample data.
-- Before running on a NEW project, replace REPLACE-WITH-ADMIN-EMAIL@example.com below with the admin's email.
-- ============================================================

-- 1. WHO IS AN ADMIN ------------------------------------------------
create table if not exists public.admins (email text primary key);
insert into public.admins (email) values ('REPLACE-WITH-ADMIN-EMAIL@example.com') on conflict do nothing;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins
                 where email = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

-- 2. TABLES -----------------------------------------------------------
create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  message text not null default 'Your time, energy, and contributions mean so much to our community. We''d love to send you a small gift as a token of our appreciation.',
  status text not null default 'open' check (status in ('draft','open','closed','archived')),
  budget numeric(10,2),
  created_at timestamptz not null default now()
);

create table if not exists public.gifts (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  name text not null,
  description text not null default '',
  image_url text,
  amazon_url text,
  est_price numeric(8,2),
  active boolean not null default true,
  sort int not null default 0
);

create table if not exists public.invitations (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  name text not null,
  email text not null,
  token text not null unique default (replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','')),
  created_at timestamptz not null default now()
);

create table if not exists public.responses (
  id uuid primary key default gen_random_uuid(),
  invitation_id uuid not null unique references public.invitations(id) on delete cascade,
  gift_id uuid not null references public.gifts(id),
  ship_name text, email text, street text, unit text, city text, state text, zip text,
  status text not null default 'to_order' check (status in ('to_order','ordered','completed')),
  notes text not null default '',
  submitted_at timestamptz not null default now(),
  address_deleted_at timestamptz
);

-- 3. PRIVACY RULES: only admins can touch the tables directly ----------
alter table public.admins      enable row level security;
alter table public.campaigns   enable row level security;
alter table public.gifts       enable row level security;
alter table public.invitations enable row level security;
alter table public.responses   enable row level security;

revoke all on public.admins, public.campaigns, public.gifts, public.invitations, public.responses from anon;

drop policy if exists admin_all on public.campaigns;
drop policy if exists admin_all on public.gifts;
drop policy if exists admin_all on public.invitations;
drop policy if exists admin_all on public.responses;
create policy admin_all on public.campaigns   for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all on public.gifts       for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all on public.invitations for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all on public.responses   for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- (admins table: no policy at all, so nobody can read it except through is_admin())

create or replace function public.am_i_admin() returns boolean
language sql stable security definer set search_path = public as $$ select public.is_admin(); $$;

-- 4. WHAT A VOLUNTEER CAN DO (only with their own secret link) -------
-- Look up their own invitation. Never returns prices, Amazon links or other people's data.
create or replace function public.get_invitation(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare inv public.invitations; camp public.campaigns; resp public.responses; g public.gifts;
begin
  if p_token is null or length(p_token) < 8 or length(p_token) > 100 then
    return jsonb_build_object('state','not_found');
  end if;
  select * into inv from public.invitations where token = p_token;
  if not found then return jsonb_build_object('state','not_found'); end if;
  select * into camp from public.campaigns where id = inv.campaign_id;
  select * into resp from public.responses where invitation_id = inv.id;
  if found then
    select * into g from public.gifts where id = resp.gift_id;
    return jsonb_build_object('state','claimed','volunteer',inv.name,'campaign',camp.name,
      'gift', jsonb_build_object('name',g.name,'description',g.description,'image_url',g.image_url),
      'email', resp.email, 'submitted_at', resp.submitted_at);
  end if;
  if camp.status <> 'open' then
    return jsonb_build_object('state','closed','campaign',camp.name);
  end if;
  return jsonb_build_object('state','open','volunteer',inv.name,'campaign',camp.name,
    'message',camp.message,'email',inv.email,
    'gifts',(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'name',x.name,'description',x.description,'image_url',x.image_url) order by x.sort, x.name),'[]'::jsonb)
             from public.gifts x where x.campaign_id = camp.id and x.active));
end $$;

-- Claim a gift. Checks everything on the server. One claim per invitation, ever.
create or replace function public.claim_gift(
  p_token text, p_gift uuid, p_name text, p_email text, p_street text,
  p_unit text, p_city text, p_state text, p_zip text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare inv public.invitations; camp public.campaigns;
  v_name text := trim(coalesce(p_name,'')); v_email text := trim(coalesce(p_email,''));
  v_street text := trim(coalesce(p_street,'')); v_unit text := trim(coalesce(p_unit,''));
  v_city text := trim(coalesce(p_city,'')); v_state text := upper(trim(coalesce(p_state,'')));
  v_zip text := trim(coalesce(p_zip,''));
begin
  if p_token is null or length(p_token) < 8 or length(p_token) > 100 then
    return jsonb_build_object('error','not_found'); end if;
  select * into inv from public.invitations where token = p_token;
  if not found then return jsonb_build_object('error','not_found'); end if;
  select * into camp from public.campaigns where id = inv.campaign_id;
  if camp.status <> 'open' then return jsonb_build_object('error','closed'); end if;
  if exists (select 1 from public.responses where invitation_id = inv.id) then
    return jsonb_build_object('error','already_claimed'); end if;
  if not exists (select 1 from public.gifts where id = p_gift and campaign_id = inv.campaign_id and active) then
    return jsonb_build_object('error','invalid','field','gift','message','Please choose one of the gifts.'); end if;
  if length(v_name) < 2 or length(v_name) > 100 then
    return jsonb_build_object('error','invalid','field','name','message','Please add your full name.'); end if;
  if v_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v_email) > 200 then
    return jsonb_build_object('error','invalid','field','email','message','That email doesn''t look quite right. Could you check it?'); end if;
  if length(v_street) < 3 or length(v_street) > 120 then
    return jsonb_build_object('error','invalid','field','street','message','Please add your street address.'); end if;
  if length(v_unit) > 40 then
    return jsonb_build_object('error','invalid','field','unit','message','That apartment or unit is a bit long.'); end if;
  if length(v_city) < 2 or length(v_city) > 80 then
    return jsonb_build_object('error','invalid','field','city','message','Please add your city.'); end if;
  if not (v_state = any (array['AL','AK','AZ','AR','CA','CO','CT','DE','DC','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY'])) then
    return jsonb_build_object('error','invalid','field','state','message','Please choose your state.'); end if;
  if v_zip !~ '^\d{5}(-\d{4})?$' then
    return jsonb_build_object('error','invalid','field','zip','message','Please enter a 5-digit ZIP code, like 98122.'); end if;
  begin
    insert into public.responses (invitation_id, gift_id, ship_name, email, street, unit, city, state, zip)
    values (inv.id, p_gift, v_name, v_email, v_street, nullif(v_unit,''), v_city, v_state, v_zip);
  exception when unique_violation then
    return jsonb_build_object('error','already_claimed');
  end;
  return public.get_invitation(p_token);
end $$;

grant execute on function public.get_invitation(text) to anon, authenticated;
grant execute on function public.claim_gift(text,uuid,text,text,text,text,text,text,text) to anon, authenticated;
grant execute on function public.am_i_admin() to authenticated;

-- 5. GIFT PHOTO STORAGE (anyone can view photos; only admins can upload) ----
insert into storage.buckets (id, name, public) values ('gift-images','gift-images',true) on conflict (id) do nothing;
drop policy if exists "admin manage gift images" on storage.objects;
create policy "admin manage gift images" on storage.objects for all to authenticated
  using (bucket_id = 'gift-images' and public.is_admin())
  with check (bucket_id = 'gift-images' and public.is_admin());

-- 6. SAMPLE CAMPAIGN so you can test right away ---------------------------
-- (Delete the two "Demo" volunteers in the dashboard before inviting real people.)
with c as (
  insert into public.campaigns (name) values ('2026 SEN Summit Volunteers') returning id
)
insert into public.gifts (campaign_id, name, description, image_url, amazon_url, sort)
select c.id, v.n, v.d, v.i, v.u, v.s from c, (values
 ('Between the World and Me','A powerful, moving read to reflect on.','images/gifts/0812983815.jpg','https://www.amazon.com/dp/0812983815',1),
 ('Tree of Hearts Note Cards','Pretty cards and envelopes to send someone a note.','images/gifts/1441324607.jpg','https://www.amazon.com/dp/1441324607',2),
 ('Hummingbird Pop-Up Card','A paper flower bouquet that springs open.','images/gifts/hummingbird.jpg','https://www.amazon.com/dp/B0DSCMBNSS',3),
 ('Astronaut Mug','A dark-blue space mug with a lid and spoon.','images/gifts/mug.jpg','https://www.amazon.com/dp/B09VBPYLKC',4),
 ('Dim Sum Pop-Up Card','A playful pop-up card that brings a smile.','images/gifts/dimsum.jpg','https://www.amazon.com/dp/B0DKF9M3G1',5),
 ('Unicorn Magnet Cars','Color-changing toy cars, for the kids in your life.','images/gifts/unicorn.jpg','https://www.amazon.com/dp/B0D6NCWSX3',6),
 ('Dandelion Herbal Tea','A soothing, caffeine-free tea for a quiet moment.','images/gifts/tea.jpg','https://www.amazon.com/dp/B0CJJ4G7FF',7),
 ('Shower Steamers','Eight scented steamers for a spa moment at home.','images/gifts/steamers.jpg','https://www.amazon.com/dp/B0DPQ8BMHM',8),
 ('Bookstore Mug','A cozy mug with a tiny bookshop on it.','images/gifts/bookmug.jpg','https://www.amazon.com/dp/B0HMR2PP5B',9)
) as v(n,d,i,u,s);

insert into public.invitations (campaign_id, name, email, token)
select id, 'Demo Volunteer One', 'demo1@example.com', 'demo-token-one-0000' from public.campaigns where name = '2026 SEN Summit Volunteers';
insert into public.invitations (campaign_id, name, email, token)
select id, 'Demo Volunteer Two', 'demo2@example.com', 'demo-token-two-0000' from public.campaigns where name = '2026 SEN Summit Volunteers';
