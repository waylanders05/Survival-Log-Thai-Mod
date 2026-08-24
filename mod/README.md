# Survival Log — Thai fan translation

แพ็กเกจนี้รองรับเกม Survival Log เวอร์ชัน 1.0.14911

## ติดตั้งแบบง่าย (แนะนำ)

1. ปิดเกมให้สนิท
2. แตก ZIP ไว้ที่ใดก็ได้
3. ดับเบิลคลิกไฟล์ `Install-ThaiMod.cmd`

ตัวติดตั้งจะค้นหาโฟลเดอร์เกมจาก Steam Library ให้อัตโนมัติ หากหาไม่พบจะเปิดหน้าต่างให้เลือกโฟลเดอร์เกมเอง

## ติดตั้งแบบ PowerShell

1. ปิดเกมให้สนิท
2. เปิด PowerShell ในโฟลเดอร์นี้ แล้วรัน:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-ThaiPrototype.ps1
```

หากติดตั้งเกมไว้คนละไดรฟ์ ให้ระบุโฟลเดอร์เกม:

```powershell
.\Install-ThaiPrototype.ps1 -GameDir 'D:\SteamLibrary\steamapps\common\Survival Log'
```

จากนั้นเปิดเกมใหม่ เลือกช่องภาษาอังกฤษที่แสดงเป็น `ไทย (ต้นแบบ)`

## ถอนการติดตั้ง

ปิดเกม แล้วดับเบิลคลิก `Uninstall-ThaiMod.cmd` ได้เลย หรือรันคำสั่ง:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Uninstall-ThaiPrototype.ps1
```

ตัวติดตั้งจะสร้างไฟล์สำรอง `.thai-prototype.backup` ก่อนแก้ไข และถอนการติดตั้งจะคืนไฟล์เดิมให้โดยอัตโนมัติ

## หมายเหตุ

- ควรติดตั้งใหม่หลังเกมอัปเดตผ่าน Steam
- ไม่แก้ไขเซฟเกม
- หาก Steam ตรวจสอบ/ซ่อมไฟล์เกม ให้รันตัวติดตั้งซ้ำ
- หากพบข้อความอังกฤษหรือการจัดวางผิดปกติ ส่งภาพพร้อมระบุฉากมาได้
