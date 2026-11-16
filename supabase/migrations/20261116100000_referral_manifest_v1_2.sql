-- Re-pins the a1-referral-v1 manifest to the v1.2 curriculum (content
-- revision 27).
--
-- 20260923100000 pinned revision 25: the free units' lesson file hashes and
-- exercise IDs as they were then. The v1.2 rebuild replaced every one of
-- those lessons, so no receipt from a current build could match, and the
-- client checks the same pins (test/domain/monetization_contract_test.dart).
--
-- The required coverage is now the scored exercises only. Unscored items
-- (data.mode predict, check or guided) are teaching and leave no evidence in
-- the player, so requiring them meant six of the eight free lessons could
-- never produce a receipt.
--
-- Generated from docs/monetization/fixtures/campaign_manifest.v1.json. Lesson
-- IDs are unchanged, so rows are updated in place. A campaign already running
-- is refused: changing what a lesson must cover mid-campaign is a decision for
-- an operator, not a deploy.
begin;

do $$
begin
  if exists(select 1 from monetization_private.referral_campaigns
            where id='a1-referral-v1' and enabled) then
    raise exception 'a1-referral-v1 is enabled; disable it before re-pinning its manifest';
  end if;
end $$;

alter table monetization_private.referral_campaigns
  drop constraint referral_campaigns_content_revision_check;

update monetization_private.referral_manifest_lessons m
set unit_id=v.unit_id, lesson_hash=v.lesson_hash, exercise_ids=v.exercise_ids, teaching_ids=v.teaching_ids
from (values
 (100,1,'fdb2d69a50f0f60b6913c00c781657c4d328b5dd9f6458d4bb5dd4bf99b2b2bf',array[1101,1102,1103,1104,1105,1106,1107,1108],array[1101,1102]),
 (101,1,'e9bb8b6033663e3182c92ae2bb6d18e137a85fe2287f4187b2028610fee41feb',array[1200,1201,1203,1205,1207,1212,1213,1214,1215,1216,1217,1218],array[1200,1201,1203,1205,1207]),
 (102,1,'bb82fa567f0cddd4d8cb6058507ee564ed573de7d1f9c970886b5c12719d276d',array[1300,1301,1303,1305,1306,1307,1308,1309,1310,1311,1312,1313,1314,1315],array[1300,1301,1303,1305,1315]),
 (103,1,'0d3bb9ac7f2ab5a731bef985a09f8fbc4cc02ce5b7e6f9d8f82ec9c448c3b597',array[1400,1401,1402,1403,1404,1405,1406,1407,1408,1409,1410,1411],array[1400,1411]),
 (201,2,'b7b646c54978cfa5ec1c19cb02822368bcca535cafd7b99ad9f0493865bef9f0',array[2101,2102,2103,2104,2105,2106,2107,2108],array[2101,2102]),
 (202,2,'a2a7c89aed3862ab8fb7f9d3c49587a93f7622509339fd7f709d9213567c36b5',array[2200,2201,2203,2205,2207,2212,2213,2214,2215,2216,2217,2218],array[2200,2201,2203,2205,2207]),
 (203,2,'a50c7c9abe91ff23ae4c43c1fb72164016cf12fb61d8d989e39b67a93c213b0a',array[2300,2301,2303,2304,2305,2306,2307,2308,2309,2310,2311,2312],array[2300,2301,2303]),
 (204,2,'79cc78fa6d4b4b198ad93f9c0de352a019819eab81da275d313dad7fd9f52475',array[2400,2401,2402,2403,2404,2405,2406,2407,2408,2409,2410],array[2400,2410])
) as v(lesson_id,unit_id,lesson_hash,exercise_ids,teaching_ids)
where m.campaign_id='a1-referral-v1' and m.lesson_id=v.lesson_id;

do $$
begin
  if (select count(*) from monetization_private.referral_manifest_lessons
      where campaign_id='a1-referral-v1') <> 8 then
    raise exception 'a1-referral-v1 manifest must hold exactly eight lessons';
  end if;
end $$;

-- Same digest format as 20260923100000, with the new revision as its prefix.
update monetization_private.referral_campaigns set content_revision=27,
  manifest_sha256=(select encode(extensions.digest('27|'||
  string_agg(unit_id::text||':'||lesson_id::text||':'||lesson_hash||':'||array_to_string(exercise_ids,',')||':'||array_to_string(teaching_ids,','),'|' order by lesson_id),'sha256'),'hex')
  from monetization_private.referral_manifest_lessons where campaign_id='a1-referral-v1')
where id='a1-referral-v1';

alter table monetization_private.referral_campaigns
  add constraint referral_campaigns_content_revision_check check (content_revision = 27);

commit;
