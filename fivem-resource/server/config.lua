-- ============================================
--        ADMIN WEB PANEL - CONFIG
-- ============================================

Config = {}

-- مفتاح الأمان (غيّره لشيء صعب!)
Config.ApiKey = "BdleKey"

-- هل تريد تسجيل كل العمليات في الكونسول؟
Config.Logging = true

-- Framework: "esx", "qbcore", "none"
Config.Framework = "qbcore"

-- أسماء الأدمنز المسموح لهم بالوصول (Steam IDs)
Config.Admins = {
    "steam:76561199610073131", -- غيّر هذا لـ Steam ID الخاص بك
}
