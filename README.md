# Sudan Bank Mobile Prototype

## التشغيل

### 1) الخادم
```bash
cd backend
python -m pip install fastapi uvicorn
uvicorn api:app --host 0.0.0.0 --port 8000
```

### 2) تطبيق Android
ثبت Flutter ثم:
```bash
cd flutter_app
flutter pub get
flutter run
```

للمحاكي Android يستخدم التطبيق `10.0.2.2` للوصول إلى الخادم المحلي.

## الحسابات التجريبية
- 249900000001 / PIN 1234
- الحساب: SD10000001
- الرصيد: 10000 SDG

المستلم:
- الحساب: SD10000002

## مهم جدًا
هذه نسخة تعليمية. قبل أي استخدام حقيقي يجب إضافة:
KYC/AML، MFA، تشفير المفاتيح، HSM، PostgreSQL، إدارة أسرار، صلاحيات مصرفية، سجل تدقيق خارجي، كشف احتيال، تسوية بين البنوك، نسخ احتياطية، Disaster Recovery، اختبارات اختراق، ومتطلبات وترخيص الجهة الرقابية السودانية.
