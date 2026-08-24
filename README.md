# Survival Log — Thai fan translation

แพ็กเกจนี้รองรับเกม Survival Log เวอร์ชัน 1.0.14956

ดาวน์โหลดรุ่นล่าสุด: [Survival_Log_Thai_1.0.14956.zip](https://github.com/waylanders05/Survival-Log-Thai-Mod/releases/download/v1.0.14956/Survival_Log_Thai_1.0.14956.zip)

รุ่นแก้ไขตัวติดตั้งนี้รองรับ Windows PowerShell 5.1 และเครื่องที่ใช้ไดรฟ์ Steam แบบกำหนดเอง

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

ตัวติดตั้งจะตรวจสอบหน้า WebUI และไฟล์ที่จำเป็นทั้งหมดก่อนเริ่มแก้ไข หากพบว่าเกมอัปเดตแล้ว จะสร้าง baseline backup ใหม่เฉพาะเมื่อไฟล์ปัจจุบันเป็นไฟล์เกมที่ยังไม่ถูกมอด และมีระบบ rollback หากเกิดข้อผิดพลาดระหว่างติดตั้ง

## หมายเหตุ

- ควรติดตั้งใหม่หลังเกมอัปเดตผ่าน Steam
- ไม่แก้ไขเซฟเกม
- หาก Steam ตรวจสอบ/ซ่อมไฟล์เกม ให้รันตัวติดตั้งซ้ำ
- หากพบข้อความอังกฤษหรือการจัดวางผิดปกติ ส่งภาพพร้อมระบุฉากมาได้
