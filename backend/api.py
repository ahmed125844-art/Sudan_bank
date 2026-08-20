
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from decimal import Decimal
import sqlite3, secrets, hashlib, hmac, time

app = FastAPI(title="Sudan Bank API", version="0.1.0")
DB="bank_api.db"

def db():
    c=sqlite3.connect(DB)
    c.row_factory=sqlite3.Row
    return c

def init():
    c=db()
    c.executescript("""
    CREATE TABLE IF NOT EXISTS users(
      id INTEGER PRIMARY KEY, name TEXT NOT NULL, phone TEXT UNIQUE NOT NULL,
      pin_hash TEXT NOT NULL, salt TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS accounts(
      id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL, account_no TEXT UNIQUE NOT NULL,
      balance TEXT NOT NULL DEFAULT '0.00',
      FOREIGN KEY(user_id) REFERENCES users(id)
    );
    CREATE TABLE IF NOT EXISTS transactions(
      id INTEGER PRIMARY KEY, tx_id TEXT UNIQUE NOT NULL, from_account INTEGER,
      to_account INTEGER, amount TEXT NOT NULL, purpose TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    """)
    if c.execute("SELECT COUNT(*) FROM users").fetchone()[0]==0:
        def hp(pin):
            salt=secrets.token_hex(16)
            h=hashlib.pbkdf2_hmac("sha256",pin.encode(),salt.encode(),200000).hex()
            return h,salt
        h,s=hp("1234")
        c.execute("INSERT INTO users(name,phone,pin_hash,salt) VALUES(?,?,?,?)",
                  ("أحمد تجريبي","249900000001",h,s))
        uid=c.lastrowid
        c.execute("INSERT INTO accounts(user_id,account_no,balance) VALUES(?,?,?)",
                  (uid,"SD10000001","10000.00"))
        h,s=hp("4321")
        c.execute("INSERT INTO users(name,phone,pin_hash,salt) VALUES(?,?,?,?)",
                  ("تاجر تجريبي","249900000002",h,s))
        uid2=c.lastrowid
        c.execute("INSERT INTO accounts(user_id,account_no,balance) VALUES(?,?,?)",
                  (uid2,"SD10000002","0.00"))
    c.commit(); c.close()

init()

class Login(BaseModel):
    phone: str
    pin: str = Field(min_length=4, max_length=8)

class Transfer(BaseModel):
    phone: str
    pin: str
    to_account: str
    amount: Decimal
    purpose: str = "تحويل"

@app.get("/health")
def health():
    return {"ok":True,"service":"Sudan Bank API"}

@app.post("/login")
def login(x: Login):
    c=db()
    u=c.execute("SELECT * FROM users WHERE phone=?",(x.phone,)).fetchone()
    if not u: raise HTTPException(401,"بيانات الدخول غير صحيحة")
    h=hashlib.pbkdf2_hmac("sha256",x.pin.encode(),u["salt"].encode(),200000).hex()
    if not hmac.compare_digest(h,u["pin_hash"]):
        raise HTTPException(401,"بيانات الدخول غير صحيحة")
    a=c.execute("SELECT * FROM accounts WHERE user_id=?",(u["id"],)).fetchone()
    c.close()
    return {"name":u["name"],"phone":u["phone"],"account_no":a["account_no"],
            "balance":a["balance"],"token":"demo-token"}

@app.post("/transfer")
def transfer(x: Transfer):
    if x.amount <= 0: raise HTTPException(400,"المبلغ غير صحيح")
    c=db()
    u=c.execute("SELECT * FROM users WHERE phone=?",(x.phone,)).fetchone()
    if not u: raise HTTPException(401,"المستخدم غير موجود")
    h=hashlib.pbkdf2_hmac("sha256",x.pin.encode(),u["salt"].encode(),200000).hex()
    if not hmac.compare_digest(h,u["pin_hash"]):
        raise HTTPException(401,"الرقم السري غير صحيح")
    src=c.execute("SELECT * FROM accounts WHERE user_id=?",(u["id"],)).fetchone()
    dst=c.execute("SELECT * FROM accounts WHERE account_no=?",(x.to_account,)).fetchone()
    if not dst: raise HTTPException(404,"الحساب المستلم غير موجود")
    if Decimal(src["balance"]) < x.amount: raise HTTPException(400,"الرصيد غير كافٍ")
    if src["account_no"]==dst["account_no"]: raise HTTPException(400,"لا يمكن التحويل للنفس")
    tx=secrets.token_hex(12)
    now=int(time.time())
    with c:
        c.execute("UPDATE accounts SET balance=? WHERE id=?",
                  (str(Decimal(src["balance"])-x.amount),src["id"]))
        c.execute("UPDATE accounts SET balance=? WHERE id=?",
                  (str(Decimal(dst["balance"])+x.amount),dst["id"]))
        c.execute("""INSERT INTO transactions
          (tx_id,from_account,to_account,amount,purpose,created_at)
          VALUES(?,?,?,?,?,?)""",
          (tx,src["id"],dst["id"],str(x.amount),x.purpose,now))
    c.close()
    return {"success":True,"tx_id":tx,"amount":str(x.amount)}

@app.get("/transactions/{account_no}")
def transactions(account_no: str):
    c=db()
    a=c.execute("SELECT * FROM accounts WHERE account_no=?",(account_no,)).fetchone()
    if not a: raise HTTPException(404,"الحساب غير موجود")
    rows=c.execute("""SELECT t.*, af.account_no from_account_no,
      at.account_no to_account_no
      FROM transactions t
      LEFT JOIN accounts af ON af.id=t.from_account
      LEFT JOIN accounts at ON at.id=t.to_account
      WHERE t.from_account=? OR t.to_account=?
      ORDER BY t.id DESC LIMIT 50""",(a["id"],a["id"])).fetchall()
    c.close()
    return [dict(r) for r in rows]
