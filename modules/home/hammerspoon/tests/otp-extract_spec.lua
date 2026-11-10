local otp = require("otp-extract")

local function cases(list)
    for _, case in ipairs(list) do
        it(case[1], function()
            assert.are.equal(case[2], otp.code(case[1]))
        end)
    end
end

describe("otp.code finds the code", function()
    cases({
        { "Your Apple Account code is: 482913. Do not share it with anyone.", "482913" },
        { "482913 is your Link verification code.", "482913" },
        { "Telegram code: 48291", "48291" },
        { "Никому не сообщайте код: 482913. После подтверждения произойдет вход", "482913" },
        { "4821 - ваш код для доступа к сервису МТС", "4821" },
        { "Код для входа в Личный кабинет Спортмастер 4821", "4821" },
        { "ПАРОЛЬ: 4821", "4821" },
        { "КоД 4821", "4821" },
        { "Ваш\194\160код:\194\160482913", "482913" },
        { "«Код» 4821", "4821" },
        { "Your code is 482 913", "482913" },
        { "Your WhatsApp code: 482-913 Don't share this code with others", "482913" },
        { "Ваш код подтверждения: 482-913. Наберите его в поле ввода.", "482913" },
        { "G-482913 is your Google verification code.", "482913" },
        { "รหัส OTP คือ 482913 (Ref: ABCD)", "482913" },
        { "รหัสยืนยัน FlashExpress ของคุณคือ 4821", "4821" },
        { "รหัสการตรวจสอบยืนยัน JIB-ONLINE รหัสอ้างอิง=ABCD, OTP=482913", "482913" },
        { "Your OTP is 482913 (Ref code 21404795). This password will be expired within 5 minutes.", "482913" },
        { "Zakaz 276414 Dostavka s 14:00 do 18:00. Vash PIN-cod 482913", "482913" },
        { "Use 4821 to sign in. Do not share this code. Call 1800 123 456 for help", "4821" },
        { "Пароль для покупки по карте MIR-1234: 7731", "7731" },
        { "Покупка 2500 RUB в магазине. Пароль 7731", "7731" },
        { "карта **** 4479, сумма 600,00 RUB. Пароль для подтверждения - 94428", "94428" },
        { "Заказ 795876, 200 руб. Код получения: 0421", "0421" },
        { "Prefer code 482193? No.", "482193" },
        { "Ваш код 4821 списан: 2026-11-03", "4821" },
        { "482913 - kod dlya vkhoda v sistemu", "482913" },
        { "Vash parol: 4821", "4821" },
        { "Код для подтверждения заказа 4821", "4821" },
    })
end)

describe("otp.code falls back to a lone six-digit number", function()
    cases({
        { "Use 482 913 to verify your Instagram account.", "482913" },
        { "Please enter 482913 into LINE within the next 30 mins.", "482913" },
        { "482913 - ", "482913" },
        { "MIR-4040 09:34 Покупка 70р Selfkiosk (107140) Баланс: 3626.85р", nil },
        { "Доступно 408343,71 RUB", nil },
    })
end)

describe("otp.code ignores numbers that are not codes", function()
    cases({
        { "Your password was changed. If this wasn't you, call 02 1234 5678", nil },
        { "Пароль изменён. Если это не вы, звоните 8 800 2000 900", nil },
        { "Promo code SUMMER: 20% off until 2026", nil },
        { "Pinterest: 12 new pins for you, 1234 views", nil },
        { "Get 1050 Baht off rides with Grab *Apply code DTACGRAB", nil },
        { "Промокод на 1000 бонусов в приложении", nil },
        { "Установлен ПИН-код для карты MIR-0564.", nil },
        { "Вам подарок! Подвеска по коду 1784Z91 в магазине", nil },
        { "Spend more 2420.- to get e-coupon 450.- code inside", nil },
        { "Thanks for the payment of 450.00 baht, customer code 3057921", nil },
        { "Hello, see you at 14:30", nil },
        { "", nil },
    })
    it("returns nil for nil", function()
        assert.is_nil(otp.code(nil))
    end)
end)

describe("otp.decodeAttributedBody", function()
    local function blob(text)
        local length = #text < 0x80 and string.char(#text) or ("\129" .. string.pack("<I2", #text))
        return "\4\11streamtyped\129\232\3\132\1@\132\132\132\8NSString\1\149\132\1+" .. length .. text .. "\134"
    end

    it("reads a short string", function()
        assert.are.equal("Код 4821", otp.decodeAttributedBody(blob("Код 4821")))
    end)

    it("reads a string with a two-byte length", function()
        local text = string.rep("я", 100)
        assert.are.equal(text, otp.decodeAttributedBody(blob(text)))
    end)

    it("returns nil for a truncated blob", function()
        assert.is_nil(otp.decodeAttributedBody(blob(string.rep("a", 200)):sub(1, 60)))
    end)

    it("returns nil without the string marker", function()
        assert.is_nil(otp.decodeAttributedBody("garbage"))
        assert.is_nil(otp.decodeAttributedBody(nil))
    end)
end)
