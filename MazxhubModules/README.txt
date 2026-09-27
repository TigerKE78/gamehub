Mazxhub Modular Structure

ไฟล์หลัก
- loader.lua  : โหลดทุก module
- config.lua  : ค่ากลาง / interval / URL
- core.lua    : Services, State, Scheduler กลาง 1 Heartbeat
- farm.lua    : Farm engine กลาง (Mob/Boss ใช้ร่วมกัน)
- boss.lua    : เลือกบอสหลายตัว / Farm Boss All โดยใช้ Farm engine
- combat.lua  : ระบบโจมตี
- skill.lua   : Auto Skill
- ui.lua      : Desktop UI

วิธีใช้
1. อัปโหลดโฟลเดอร์ MazxhubModules ไป GitHub
2. แก้ BASE ใน loader.lua ให้เป็น raw URL ของ repo
3. รัน loader.lua
4. ย้าย logic จาก hello.txt เข้า module ทีละส่วน

ตำแหน่งที่ควรย้ายจาก hello.txt
- Farm / farmMoveUnder / target finding -> farm.lua
- Multi Boss / Boss All / BOSS_TYPES -> boss.lua
- CombatRuntime / Fast Attack / Block / Combo -> combat.lua
- AutoSkills -> skill.lua
- Section / Toggle / Slider / pages -> ui.lua

สถานะการย้ายระบบ
- Farm จริงถูกย้ายจาก hello.txt เข้า farm.lua แล้ว
- มี farmActiveFolder / farmActiveFolderForName / farmFindMobsByName
- มี farmBossFolder / farmBossModel / farmFindBossByName
- มี farmNearestByName / farmMoveUnder
- มี farmStart / farmStop / farmSet
- การลอยเหนือหัว + prone ใช้ AlignPosition/AlignOrientation แบบเดิม
- Boss module ใช้ Farm.TargetResolver ของจริงแล้ว

ยังเป็น placeholder:
- Combat.AttackDriver ยังใช้ Tool:Activate()
  ให้ย้าย Combat_Service / Remote ของจริงจาก hello.txt มาแทนใน combat.lua ภายหลัง

เป้าหมายของโครงนี้
- แยก compile chunk ลดปัญหา local registers 200
- ใช้ Heartbeat กลางตัวเดียว
- Boss ไม่สร้าง farm loop ใหม่
- UI ไม่ปนกับ combat/farm logic
- แก้ระบบหนึ่งโดยไม่ต้องแก้ไฟล์ใหญ่ทั้งไฟล์


Loader ใหม่
- DEFAULT_BASE ใน loader.lua ต้องเป็น raw GitHub URL ของโฟลเดอร์ MazxhubModules
- หรือกำหนดก่อนรัน:
  getgenv().MAZX_BASE = "https://raw.githubusercontent.com/USER/REPO/main/MazxhubModules/"

ตรวจเกม
- config.lua > Game.Strict = false : อนุญาตทุกเกมระหว่างพัฒนา
- Game.Strict = true : ต้องตรงอย่างน้อยหนึ่งรายการใน PlaceIds / GameIds / CreatorIds
- GameIds หมายถึง game.GameId (Universe ID)

การโหลด
- config.lua โหลดก่อน
- ตรวจเกม
- core.lua โหลดและตรวจ Core:Create
- preload farm/boss/combat/skill/ui ให้ครบ
- Init: Farm -> Boss -> Combat -> Skill -> UI
- Start: Farm -> Combat -> Skill -> UI
- ถ้า download/compile/execute/Init/Start ล้มเหลว จะแจ้ง [Mazxhub/Loader] FAILED
- HTTP retry ตั้งได้ที่ config.lua > Loader.Retries / RetryDelay
- Mazxhub ตัวเก่าจะถูก Shutdown หลังตัวใหม่ Start สำเร็จ


อัปเดตการย้ายระบบหลัก
- Farm: ย้าย target scan, boss scan, nearest target, hover/prone, camera stabilizer, start/stop/set แล้ว
- Boss: ย้าย selection / Farm Boss All / rescan เมื่อเปลี่ยนติ๊ก / stop เมื่อ selection ว่างแล้ว
- Combat: ย้าย Item_Equip, Mouse/Tool/Combat_Service drivers, Fast Attack, combo gate, F guard หลัง hit 5, background signal driver แล้ว
- Skill: ย้าย Auto Skill Z/X/C/V/B/N/K, interval, prone lock และ scheduler กลางแล้ว
- UI: เปลี่ยนเป็น Desktop modular UI สำหรับ Farm/Boss/Combat/Skill พร้อม Fab ด้านบนและ RightShift แล้ว
- Core: ยังใช้ Heartbeat scheduler กลางตัวเดียว
- hello.txt เดิมยังเก็บไว้เป็น legacy/backup และยังไม่ได้ลบระบบเก่าออก

สิ่งที่ยังไม่ได้ย้ายจาก hello.txt เพราะอยู่นอก 5 module แรก:
Quest/Dungeon/Raid Chest/Betty/Kazu/Delivery/Pages/Bear/Thunder Training/Cup Game/Pushups/Player Mods/Invisible/Visuals/Teleport
