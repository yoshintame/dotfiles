local M = {}

local INLINE_SPACES = { [" "] = true, ["\u{a0}"] = true, ["\u{202f}"] = true, ["\u{2009}"] = true }
local LINE_SPACES = { ["\t"] = true, ["\n"] = true, ["\r"] = true }

local function set(...)
    local result = {}
    for _, list in ipairs({ ... }) do
        for _, item in ipairs(list) do result[item] = true end
    end
    return result
end

local function isSpace(char)
    return INLINE_SPACES[char] or LINE_SPACES[char]
end

local function script(char)
    if #char == 1 then return char:match("%a") and "latin" or nil end
    local b1, b2 = char:byte(1, 2)
    if b1 == 0xD0 or b1 == 0xD1 then return "cyrillic" end
    if b1 >= 0xC3 and b1 <= 0xCF then return "latin" end
    if b1 == 0xE0 and (b2 == 0xB8 or b2 == 0xB9) then return "thai" end
    return nil
end

local function lower(word)
    return (word
        :gsub("[A-Z]", function(c) return string.char(c:byte() + 32) end)
        :gsub("\208\129", "\209\145")
        :gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
        :gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end))
end

local function startsWithAny(word, prefixes)
    for _, prefix in ipairs(prefixes) do
        if word:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function tokenize(text)
    local tokens = {}
    for char in text:gmatch(utf8.charpattern) do
        local kind, class
        if char:match("^%d$") then
            kind = "num"
        elseif isSpace(char) then
            kind = "space"
        else
            class = script(char)
            kind = class and "word" or "punct"
        end
        local last = tokens[#tokens]
        if last and last.kind == kind and kind ~= "punct" and last.class == class then
            last.raw = last.raw .. char
        else
            tokens[#tokens + 1] = { kind = kind, class = class, raw = char }
        end
    end
    for _, token in ipairs(tokens) do
        if token.kind == "word" then token.lower = lower(token.raw) end
    end
    return tokens
end

local function nearbyWords(tokens, from, step, limit)
    local words, i = {}, from
    while tokens[i] and #words < limit do
        if tokens[i].kind == "word" then
            words[#words + 1] = tokens[i].lower
        elseif tokens[i].kind == "num" then
            break
        end
        i = i + step
    end
    return words
end

local function gap(tokens, from, to)
    local count = 0
    for i = from + 1, to - 1 do
        local kind = tokens[i].kind
        if kind == "word" or kind == "num" then count = count + 1 end
    end
    return count
end

local function parenthesized(tokens, k, j)
    local before, after = tokens[k - 1], tokens[j + 1]
    return before ~= nil and after ~= nil and before.raw == "(" and after.raw == ")"
end

function M.new(rules)
    local digits = rules.digits
    local exactKeywords = set(rules.keywords.exact)
    local keywordPrefixes = rules.keywords.prefixes
    local substringKeywords = rules.keywords.substrings
    local notOtpQualifiers = set(rules.notOtpQualifiers)
    local unitWords = set(rules.units.words)
    local unitPrefixes = rules.units.prefixes
    local unitSigns = set(rules.units.signs, rules.currencySigns)
    local glueBefore = set(rules.glue.before, rules.currencySigns)
    local glueAfter = set(rules.glue.after, rules.currencySigns)

    local function hasSubstringKeyword(word)
        for keyword, exclusions in pairs(substringKeywords) do
            local init = 1
            while true do
                local s = word:find(keyword, init, true)
                if not s then break end
                local excluded = false
                for _, phrase in ipairs(exclusions) do
                    if word:sub(s, s + #phrase - 1) == phrase then excluded = true end
                end
                if not excluded then return true end
                init = s + #keyword
            end
        end
        return false
    end

    local function isKeyword(tokens, index)
        local word = tokens[index].lower
        if exactKeywords[word] then
            local previous = nearbyWords(tokens, index - 1, -1, 1)[1]
            return not (previous and notOtpQualifiers[previous])
        end
        return startsWithAny(word, keywordPrefixes) or hasSubstringKeyword(word)
    end

    local function joinable(token)
        return token ~= nil and (INLINE_SPACES[token.raw] or token.raw == "-")
    end

    local function digitGroup(tokens, k)
        local pieces, j = { tokens[k].raw }, k
        while joinable(tokens[j + 1]) and tokens[j + 2] and tokens[j + 2].kind == "num" do
            pieces[#pieces + 1] = tokens[j + 2].raw
            j = j + 2
        end
        if #pieces == 1 and #pieces[1] >= digits.min and #pieces[1] <= digits.max then
            return pieces[1], j
        end
        if #pieces == 2 and #pieces[1] == 3 and #pieces[2] == 3 then
            return pieces[1] .. pieces[2], j
        end
        return nil, j
    end

    local function attachedBefore(tokens, k)
        local prev = tokens[k - 1]
        if not prev then return false end
        if prev.kind == "word" then return true end
        if prev.kind ~= "punct" then return false end
        if glueBefore[prev.raw] then return true end
        local beforePrev = tokens[k - 2]
        if prev.raw == "-" and beforePrev and beforePrev.kind == "word" then
            return #beforePrev.raw > 1
        end
        return (prev.raw == "." or prev.raw == ",") and beforePrev ~= nil and beforePrev.kind == "num"
    end

    local function attachedAfter(tokens, j)
        local next = tokens[j + 1]
        if not next then return false end
        if next.kind == "word" then return true end
        if next.kind ~= "punct" then return false end
        if glueAfter[next.raw] then return true end
        local afterNext = tokens[j + 2]
        if next.raw == "." or next.raw == "," or next.raw == ":" then
            return afterNext ~= nil and (afterNext.kind == "num" or afterNext.raw == "-")
        end
        return false
    end

    local function followedByUnit(tokens, j)
        local i = j + 1
        if tokens[i] and tokens[i].kind == "space" then i = i + 1 end
        local token = tokens[i]
        if not token then return false end
        if token.kind == "punct" then return unitSigns[token.raw] == true end
        if token.kind ~= "word" then return false end
        return unitWords[token.lower] == true or startsWithAny(token.lower, unitPrefixes)
    end

    return function(text)
        if not text or text == "" then return nil end
        local tokens = tokenize(text)
        local keywords = {}
        for i, token in ipairs(tokens) do
            if token.kind == "word" and isKeyword(tokens, i) then keywords[#keywords + 1] = i end
        end
        local best, bestRank, fallback
        local k = 1
        while k <= #tokens do
            if tokens[k].kind == "num" then
                local candidate, j = digitGroup(tokens, k)
                if candidate
                    and not attachedBefore(tokens, k)
                    and not attachedAfter(tokens, j)
                    and not followedByUnit(tokens, j) then
                    if not fallback and #candidate == digits.fallback and not parenthesized(tokens, k, j) then
                        fallback = candidate
                    end
                    local preference = #candidate <= digits.typicalMax and 0 or 1
                    for _, index in ipairs(keywords) do
                        local distance = index < k and gap(tokens, index, k) or gap(tokens, j, index)
                        local rank = preference * (digits.maxGap + 1) + distance
                        if distance <= digits.maxGap and (not bestRank or rank < bestRank) then
                            best, bestRank = candidate, rank
                        end
                    end
                end
                k = j + 1
            else
                k = k + 1
            end
        end
        return best or fallback
    end
end

local TYPEDSTREAM_STRING = "NSString"
local TYPEDSTREAM_HEADER = 5

function M.decodeAttributedBody(blob)
    if not blob then return nil end
    local i = blob:find(TYPEDSTREAM_STRING, 1, true)
    if not i then return nil end
    local p = i + #TYPEDSTREAM_STRING + TYPEDSTREAM_HEADER
    local length = blob:byte(p)
    if not length then return nil end
    p = p + 1
    local width = (length == 0x81 and 2) or (length == 0x82 and 4) or 0
    if width > 0 then
        if #blob < p + width - 1 then return nil end
        length = string.unpack(width == 2 and "<I2" or "<I4", blob, p)
        p = p + width
    end
    if #blob < p + length - 1 then return nil end
    return blob:sub(p, p + length - 1)
end

return M
