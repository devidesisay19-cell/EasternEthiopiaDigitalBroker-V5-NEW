-- Seed: 4 pilot cities (Region > Zone > City). Safe to re-run.
-- Woredas / areas can be added later with the same pattern (type 'woreda' / 'area').
do $$
declare
  rec record; v_region uuid; v_zone uuid;
begin
  for rec in select * from (values
    ('Dire Dawa','Dire Dawa','Dire Dawa'),
    ('Harari','Harari','Harar'),
    ('Somali','Fafan','Jigjiga'),
    ('Oromia','West Hararghe','Chiro')
  ) as t(region_name, zone_name, city_name)
  loop
    select id into v_region from public.locations where type='region' and name=rec.region_name limit 1;
    if v_region is null then
      insert into public.locations(name,type) values (rec.region_name,'region') returning id into v_region;
    end if;
    select id into v_zone from public.locations where type='zone' and name=rec.zone_name and parent_id=v_region limit 1;
    if v_zone is null then
      insert into public.locations(name,type,parent_id) values (rec.zone_name,'zone',v_region) returning id into v_zone;
    end if;
    if not exists (select 1 from public.locations where type='city' and name=rec.city_name and parent_id=v_zone) then
      insert into public.locations(name,type,parent_id) values (rec.city_name,'city',v_zone);
    end if;
  end loop;
end $$;
