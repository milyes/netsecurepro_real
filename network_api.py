import os,json
from flask import Flask,jsonify
app=Flask(__name__)
F=os.path.expanduser("~/.network_detect/wifi_results.json")
@app.route('/')
def index(): return jsonify({"app":"NetSecurePro API v1.2.0","status":"OK"})
@app.route('/api/wifi')
def wifi():
 d=[]; 
 if os.path.exists(F): 
  try: d=json.load(open(F))
  except: pass
 best=max(d,key=lambda x:-float(x.get("rssi",-100))) if d else None
 return jsonify({"statut":"succes","meilleur":best,"total":len(d)})
if __name__=='__main__': app.run(host='0.0.0.0',port=5000)
