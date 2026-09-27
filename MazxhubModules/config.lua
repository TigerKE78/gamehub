-- MazxhubModules/config.lua
-- ค่ากลางที่แก้ได้โดยไม่ต้องแตะ logic ของระบบ

return {
    Version = "0.1.0",

    -- เปลี่ยนเป็น raw GitHub ของคุณก่อนใช้งาน loader แบบออนไลน์
    BaseURL = "https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/MazxhubModules/",

    -- ตรวจว่า loader กำลังรันอยู่ในเกมที่รองรับหรือไม่
    -- Strict = false = ยังอนุญาตทุกเกมระหว่างพัฒนา
    -- เมื่อพร้อมใช้งานจริงให้เปลี่ยนเป็น true แล้วใส่ ID ที่ต้องการ
    Game = {
        Strict = false,
        PlaceIds = {
            -- 136406881576517,
        },
        GameIds = {
            -- Universe ID เช่น game.GameId
        },
        CreatorIds = {
            -- Creator/User/Group ID เช่น game.CreatorId
        },
    },

    Loader = {
        Retries = 3,
        RetryDelay = 0.35,
    },

    Intervals = {
        Farm = 0.10,
        Combat = 0.02,
        Skill = 0.05,
    },

    Farm = {
        MoveAboveTarget = true,
        HeightAboveHead = 3,
        AttackRange = 12,
    },

    Skill = {
        Z = { Enabled = false, Interval = 1.0 },
        X = { Enabled = false, Interval = 1.0 },
        C = { Enabled = false, Interval = 1.0 },
        V = { Enabled = false, Interval = 1.0 },
        B = { Enabled = false, Interval = 1.0 },
        N = { Enabled = false, Interval = 1.0 },
        K = { Enabled = false, Interval = 1.0 },
    },
}
