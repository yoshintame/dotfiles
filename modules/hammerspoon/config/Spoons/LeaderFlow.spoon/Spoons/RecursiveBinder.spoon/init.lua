--- === RecursiveBinder ===
---
--- A spoon that let you bind sequential bindings.
--- It also (optionally) shows a bar about current keys bindings.
---
--- [Click to download](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/RecursiveBinder.spoon.zip)
---@diagnostic disable: undefined-global

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "RecursiveBinder"
obj.version = "0.7"
obj.author = "Yuan Fu <casouri@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- RecursiveBinder.escapeKey
--- Variable
--- key to abort, default to {keyNone, 'escape'}
obj.escapeKey = { keyNone, 'escape' }

--- RecursiveBinder.helperEntryEachLine
--- Variable
--- Number of entries each line of helper. Default to 5.
obj.helperEntryEachLine = 5

--- RecursiveBinder.helperEntryLengthInChar
--- Variable
--- Length of each entry in char. Default to 20.
obj.helperEntryLengthInChar = 20

--- RecursiveBinder.helperFormat
--- Variable
--- format of helper, the helper is just a hs.alert
---
--- Notes:
---  * default to {atScreenEdge=2,
---             strokeColor={ white = 0, alpha = 2 },
---             textFont='SF Mono'
---             textSize=20}
obj.helperFormat = {
  atScreenEdge = 2,
  strokeColor = { white = 0, alpha = 2 },
  textFont = 'Courier',
  textSize = 20
}

--- RecursiveBinder.showBindHelper()
--- Variable
--- whether to show helper, can be true of false
obj.showBindHelper = true

--- RecursiveBinder.helperModifierMapping()
--- Variable
--- The mapping used to display modifiers on helper.
---
--- Notes:
---  * Default to {
---  command = '⌘',
---  control = '⌃',
---  option = '⌥',
---  shift = '⇧',
--- }
obj.helperModifierMapping = {
  command = '⌘',
  control = '⌃',
  option = '⌥',
  shift = '⇧',
}

-- used by next model to close previous helper
local previousHelperID = nil

-- this function is used by helper to display
-- appropriate 'shift + key' bindings
-- it turns a lower key to the corresponding
-- upper key on keyboard
local function keyboardUpper(key)
  local upperTable = {
    a = 'A',
    b = 'B',
    c = 'C',
    d = 'D',
    e = 'E',
    f = 'F',
    g = 'G',
    h = 'H',
    i = 'I',
    j = 'J',
    k = 'K',
    l = 'L',
    m = 'M',
    n = 'N',
    o = 'O',
    p = 'P',
    q = 'Q',
    r = 'R',
    s = 'S',
    t = 'T',
    u = 'U',
    v = 'V',
    w = 'W',
    x = 'X',
    y = 'Y',
    z = 'Z',
    ['`'] = '~',
    ['1'] = '!',
    ['2'] = '@',
    ['3'] = '#',
    ['4'] = '$',
    ['5'] = '%',
    ['6'] = '^',
    ['7'] = '&',
    ['8'] = '*',
    ['9'] = '(',
    ['0'] = ')',
    ['-'] = '_',
    ['='] = '+',
    ['['] = '}',
    [']'] = '}',
    ['\\'] = '|',
    [';'] = ':',
    ['\''] = '"',
    [','] = '<',
    ['.'] = '>',
    ['/'] = '?'
  }
  uppperKey = upperTable[key]
  if uppperKey then
    return uppperKey
  else
    return key
  end
end

--- RecursiveBinder.singleKey(key, name)
--- Method
--- this function simply return a table with empty modifiers also it translates capital letters to normal letter with shift modifer
---
--- Parameters:
---  * key - a letter
---  * name - the description to pass to the keys binding function
---
--- Returns:
---  * a table of modifiers and keys and names, ready to be used in keymap
---    to pass to RecursiveBinder.recursiveBind()
function obj.singleKey(key, name)
  local mod = {}
  if key == keyboardUpper(key) and string.len(key) == 1 then
    mod = { 'shift' }
    key = string.lower(key)
  end

  if name then
    return { mod, key, name }
  else
    return { mod, key, 'no name' }
  end
end

-- generate a string representation of a key spec
-- {{'shift', 'command'}, 'a} -> 'shift+command+a'
local function createKeyName(key)
  -- key is in the form {{modifers}, key, (optional) name}
  -- create proper key name for helper
  local modifierTable = key[1]
  local keyString = key[2]
  -- add a little mapping for space
  if keyString == 'space' then keyString = 'SPC' end
  if #modifierTable == 1 and modifierTable[1] == 'shift' and string.len(keyString) == 1 then
    return keyboardUpper(keyString)
  else
    local keyName = ''
    if #modifierTable >= 1 then
      for count = 1, #modifierTable do
        local modifier = modifierTable[count]
        if count == 1 then
          keyName = obj.helperModifierMapping[modifier] .. ' + '
        else
          keyName = keyName .. obj.helperModifierMapping[modifier] .. ' + '
        end
      end
    end
    return keyName .. keyString
  end
end

local function compareLetters(a, b)
  local asciiA = string.byte(a)
  local asciiB = string.byte(b)
  if asciiA >= 65 and asciiA <= 90 then
    asciiA = asciiA + 32.5
  end
  if asciiB >= 65 and asciiB <= 90 then
    asciiB = asciiB + 32.5
  end
  return asciiA < asciiB
end

local function showHelper(keyFuncNameTable)
  local helper = ''
  local separator = ''
  local count = 0

  local sortedKeyFuncNameTable = {}
  for keyName, funcName in pairs(keyFuncNameTable) do
    table.insert(sortedKeyFuncNameTable, { keyName = keyName, funcName = funcName })
  end
  table.sort(sortedKeyFuncNameTable, function(a, b) return compareLetters(a.keyName, b.keyName) end)

  for _, value in ipairs(sortedKeyFuncNameTable) do
    local keyName = value.keyName
    local funcName = value.funcName
    local newEntry = keyName .. ' → ' .. funcName
    if string.len(newEntry) > obj.helperEntryLengthInChar then
      newEntry = string.sub(newEntry, 1, obj.helperEntryLengthInChar - 2) .. '..'
    elseif string.len(newEntry) < obj.helperEntryLengthInChar then
      newEntry = newEntry .. string.rep(' ', obj.helperEntryLengthInChar - string.len(newEntry))
    end
    if count == 0 then
      separator = ''
    elseif count % obj.helperEntryEachLine == 0 then
      separator = '\n'
    else
      separator = '  '
    end
    helper = helper .. separator .. newEntry
    count = count + 1
  end
  previousHelperID = hs.alert.show(helper, obj.helperFormat, true)
end

local function killHelper()
  hs.alert.closeSpecific(previousHelperID)
end

function obj.recursiveBind(keymap, modals)
  if not modals then modals = {} end
  if type(keymap) == 'function' then
    return keymap
  end
  local modal = hs.hotkey.modal.new()
  table.insert(modals, modal)
  local keyFuncNameTable = {}
  for key, map in pairs(keymap) do
    local func = obj.recursiveBind(map, modals)
    modal:bind(key[1], key[2], function()
      modal:exit()
      killHelper()
      func()
    end)
    modal:bind(obj.escapeKey[1], obj.escapeKey[2], function()
      modal:exit()
      killHelper()
    end)
    if #key >= 3 then
      keyFuncNameTable[createKeyName(key)] = key[3]
    end
  end
  return function()
    for _, m in pairs(modals) do
      m:exit()
    end
    modal:enter()
    killHelper()
    if obj.showBindHelper then
      showHelper(keyFuncNameTable)
    end
  end
end

return obj


