begin;
select plan(24);
select is((select count(*)::integer from pg_tables where schemaname='public'),16,'Four modules retain sixteen public tables');
select ok(not has_function_privilege('authenticated','public.claim_storage_cleanup(integer)','EXECUTE'),'Users cannot claim cleanup jobs');
select ok(not has_function_privilege('authenticated','public.validate_storage_cleanup(uuid,uuid)','EXECUTE'),'Users cannot validate cleanup leases');
select ok(not has_function_privilege('authenticated','public.finish_storage_cleanup(uuid,uuid,boolean)','EXECUTE'),'Users cannot finalize cleanup');
select ok(not has_function_privilege('authenticated','public.begin_account_deletion(uuid,uuid,boolean)','EXECUTE'),'Administrative deletion cannot be called by user RPC');
select ok(not has_function_privilege('authenticated','public.claim_account_deletions(integer)','EXECUTE'),'Users cannot claim foreign accounts');
select ok(not has_table_privilege('authenticated','private.account_deletions','SELECT'),'Deletion state is private');
select ok(not has_table_privilege('authenticated','private.moderation_operators','INSERT'),'Users cannot assign moderator role');
select ok(not has_table_privilege('authenticated','private.moderation_actions','SELECT'),'Operator audit hidden from ordinary users');
select ok(not has_table_privilege('authenticated','private.moderation_restrictions','UPDATE'),'Users cannot lift moderation restrictions');
select ok(has_function_privilege('service_role','public.claim_storage_cleanup(integer)','EXECUTE'),'Server may consume existing queue');
select ok(has_function_privilege('authenticated','public.moderation_reports(integer,uuid)','EXECUTE'),'Role-checked moderation entry point');
select ok(not has_function_privilege('authenticated','private.require_moderator()','EXECUTE'),'Authorization helper not exposed');
select ok(exists(select 1 from pg_trigger where tgrelid='storage.objects'::regclass and tgname='storage_path_fence'),'Uploads coordinate with deletion fence');
select ok(exists(select 1 from pg_trigger where tgrelid='public.recipes'::regclass and tgname='photo_reference_fence'),'Recipe links coordinate with fence');
select ok(exists(select 1 from pg_trigger where tgrelid='public.profiles'::regclass and tgname='photo_reference_fence'),'Avatar links coordinate with fence');
select is((select count(*)::integer from pg_policies where schemaname='public' and policyname='active_account'),16,'Deleted UID blocked across every public table');
select ok(exists(select 1 from pg_policies where schemaname='storage' and policyname='active_account'),'Deleted UID blocked in Storage');
select ok(private.cleanup_valid_path('recipe-photos','00000000-0000-4000-8000-000000000001/00000000-0000-4000-8000-000000000002/00000000-0000-4000-8000-000000000003.jpg'),'Strict recipe path accepted');
select ok(not private.cleanup_valid_path('recipe-photos','../other.jpg') and not private.cleanup_valid_path('other','00000000-0000-4000-8000-000000000001/00000000-0000-4000-8000-000000000003.jpg'),'Traversal and unknown bucket denied');
-- SQL policy fixtures in rollback, separate from real GoTrue/Storage tests.
insert into auth.users(id,email) values('80000000-0000-4000-8000-000000000001','release-avatar-sql@example.test');
insert into public.profiles(user_id,username,display_name) values('80000000-0000-4000-8000-000000000001','release_avatar_sql','SQL avatar');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"80000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select ok(private.avatar_access('80000000-0000-4000-8000-000000000001/80000000-0000-4000-8000-000000000002.png',true),'Valid full UUID avatar path remains writable by owner');
select ok(not private.avatar_access('80000000-0000-4000-8000-000000000003/80000000-0000-4000-8000-000000000002.png',true),'Foreign avatar path stays denied');
reset role;
-- Exercise finite retention, not just the existence of a maintenance function.
insert into private.storage_cleanup_jobs(id,bucket_id,object_name,state,finished_at)
values('81000000-0000-4000-8000-000000000001','profile-avatars',
 '80000000-0000-4000-8000-000000000001/81000000-0000-4000-8000-000000000001.png','done',clock_timestamp()-interval '31 days');
insert into private.storage_cleanup_jobs(id,bucket_id,object_name,state,fenced,error_code,finished_at)
values('81000000-0000-4000-8000-000000000002','profile-avatars',
 '80000000-0000-4000-8000-000000000001/81000000-0000-4000-8000-000000000002.png','dead',true,'storage_failure',clock_timestamp()-interval '31 days');
insert into private.account_deletions(id,actor_hash,request_id,state,finished_at)
values('81000000-0000-4000-8000-000000000003',repeat('8',64),
 '81000000-0000-4000-8000-000000000004','done',clock_timestamp()-interval '31 days');
insert into private.moderation_actions(id,action,created_at)
values('81000000-0000-4000-8000-000000000005','review',clock_timestamp()-interval '31 days');
do $$ begin perform private.maintain_private_operations(); end $$;
select ok(not exists(select 1 from private.storage_cleanup_jobs where id='81000000-0000-4000-8000-000000000001')
 and not exists(select 1 from private.account_deletions where id='81000000-0000-4000-8000-000000000003')
 and not exists(select 1 from private.moderation_actions where id='81000000-0000-4000-8000-000000000005'),
 'Completed physical/account/audit traces purged after thirty days');
select ok(exists(select 1 from private.storage_cleanup_jobs where id='81000000-0000-4000-8000-000000000002'),
 'Unresolved fenced deadletter remains visible instead of silently losing deletion');
select * from finish();
rollback;
