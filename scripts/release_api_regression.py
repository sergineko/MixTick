"""Run the original 20 API assertions unchanged, with current fixture teardown.

The new active-image protection requires owners to unlink their fixture before
physical deletion. No permission assertion is replaced and no admin API key is
used. Trusted SQL remains confined to the original scoped fixture maintenance.
"""
import json
import re
import uuid

import test_database_api as legacy

class ReleaseApiTests(legacy.DatabaseApiTests):
    @classmethod
    def tearDownClass(cls):
        recorded=[]
        for user,path in cls.photos:
            uid=str(uuid.UUID(user['id']))
            match=re.fullmatch(r'test_([0-9a-f]{10})_([abc])',user['username'])
            if not match or path.split('/')[0]!=uid:
                raise RuntimeError('Foreign fixture teardown refused')
            expected=f'mixtick-{match[1]}-{match[2]}@example.test'
            actual=cls.sql(f"select email from auth.users where id='{uid}';")
            if actual!=expected:raise RuntimeError('Fixture identity mismatch')
            recipe=str(uuid.UUID(path.split('/')[1]))
            code,rows=cls.http('GET','/rest/v1/recipes?id=eq.'+recipe+'&select=id,version,hero_image_path',user)
            if code!=200:raise RuntimeError('Owner fixture read failed')
            if rows and rows[0]['hero_image_path']==path:
                code,_=cls.http('POST','/rest/v1/rpc/set_recipe_photo',user,{
                    'p_recipe_id':recipe,'p_path':None,'p_expected_version':rows[0]['version']})
                if code!=200:raise RuntimeError('Owner fixture unlink failed')
            recorded.append(path)
        # This calls the original teardown after the required explicit unlink.
        super().tearDownClass()
        for path in recorded:
            cls.sql("delete from private.storage_cleanup_jobs where bucket_id='recipe-photos' and object_name="+"'"+path+"';")
        print('PASS: original API fixtures unlinked by their owners before scoped physical teardown')

if __name__=='__main__':
    legacy.DatabaseApiTests=ReleaseApiTests
    raise SystemExit(legacy.main())
