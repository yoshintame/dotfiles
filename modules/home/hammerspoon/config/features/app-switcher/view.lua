local M = {}

local icons = {}

local function iconFor(app)
    local id = app:bundleID()
    if not id then return nil end
    if icons[id] == nil then icons[id] = hs.image.imageFromAppBundle(id) or false end
    return icons[id] or nil
end

local function layout(c, appCount, windowCount, screenWidth)
    local inset = c.margin + c.highlightInset
    local appRow = appCount * c.iconSize + (appCount - 1) * c.gap
    local fit = (screenWidth * c.maxScreenShare - inset * 2 - (windowCount - 1) * c.gap) / math.max(windowCount, 1)
    local previewW = math.max(1, math.min(c.preview.width, fit))
    local previewH = previewW * c.preview.aspect
    local windowRow = windowCount > 0 and windowCount * previewW + (windowCount - 1) * c.gap or 0
    local content = math.max(appRow, windowRow)
    local appLeft = inset + (content - appRow) / 2
    local windowLeft = inset + (content - windowRow) / 2
    local labelY = inset + c.iconSize + c.highlightInset + c.labelGap
    local previewY = labelY + c.labelHeight + c.sectionGap + c.highlightInset
    local titleY = previewY + previewH + c.labelGap
    local baseHeight = labelY + c.labelHeight + c.margin
    local function grow(f)
        return { x = f.x - c.highlightInset, y = f.y - c.highlightInset, w = f.w + c.highlightInset * 2, h = f.h + c.highlightInset * 2 }
    end
    local function icon(i)
        return { x = appLeft + (i - 1) * (c.iconSize + c.gap), y = inset, w = c.iconSize, h = c.iconSize }
    end
    local function preview(j)
        return { x = windowLeft + (j - 1) * (previewW + c.gap), y = previewY, w = previewW, h = previewH }
    end
    return {
        width = content + inset * 2,
        height = windowCount > 0 and titleY + c.labelHeight + c.highlightInset + c.margin or baseHeight,
        baseHeight = baseHeight,
        slotRadius = c.radius / 2,
        previewRadius = c.radius / 3,
        icon = icon,
        slot = function(i) return grow(icon(i)) end,
        label = { x = inset, y = labelY, w = content, h = c.labelHeight },
        preview = preview,
        title = function(j)
            local f = preview(j)
            return { x = f.x, y = titleY, w = f.w, h = c.labelHeight }
        end,
        card = function(j)
            local f = preview(j)
            return grow({ x = f.x, y = f.y, w = f.w, h = titleY + c.labelHeight - f.y })
        end,
        fit = function(j, size)
            local box = preview(j)
            local scale = math.min(box.w / size.w, box.h / size.h)
            local w, h = size.w * scale, size.h * scale
            return { x = box.x + (box.w - w) / 2, y = box.y + (box.h - h) / 2, w = w, h = h }
        end,
    }
end

local function text(c, value, frame, size)
    return {
        type = "text",
        text = value,
        textAlignment = "center",
        textColor = c.text,
        textSize = size,
        textLineBreak = "truncateTail",
        frame = frame,
    }
end

local function rectangle(color, frame, radius, id)
    return {
        id = id,
        type = "rectangle",
        action = "fill",
        fillColor = color,
        roundedRectRadii = { xRadius = radius, yRadius = radius },
        trackMouseEnterExit = id ~= nil,
        trackMouseMove = id ~= nil,
        frame = frame,
    }
end

local function previewElements(c, cached, frame)
    local radius = cached.cornerRatio * frame.w
    local edge = c.preview.edgeInset
    return {
        type = "rectangle",
        action = "clip",
        roundedRectRadii = { xRadius = radius, yRadius = radius },
        frame = { x = frame.x + edge, y = frame.y + edge, w = frame.w - edge * 2, h = frame.h - edge * 2 },
    }, { type = "image", image = cached.image, imageScaling = "scaleToFit", frame = frame }, { type = "resetClip" }
end

function M.render(canvas, s, c, previewOf)
    local app = s.apps[s.appIndex]
    local windows = s.row and s.row.windows or {}
    local geo = layout(c, #s.apps, #windows, s.screen.w)
    canvas:frame({
        x = s.screen.x + (s.screen.w - geo.width) / 2,
        y = s.screen.y + (s.screen.h - geo.baseHeight) / 2,
        w = geo.width,
        h = geo.height,
    })
    local elements = {
        rectangle(c.background, nil, c.radius),
        rectangle(c.highlight, geo.slot(s.appIndex), geo.slotRadius),
    }
    if s.row then elements[#elements + 1] = rectangle(c.highlight, geo.card(s.row.index), geo.slotRadius) end
    local targets = {}
    for i, candidate in ipairs(s.apps) do
        local image = iconFor(candidate)
        if image then
            local id = "app" .. i
            if i ~= s.appIndex then targets[id] = { app = i } end
            elements[#elements + 1] = {
                id = id,
                type = "image",
                image = image,
                trackMouseEnterExit = true,
                trackMouseMove = true,
                frame = geo.icon(i),
            }
        end
    end
    elements[#elements + 1] = text(c, app:name() or "", geo.label, c.textSize)
    for j, entry in ipairs(windows) do
        local id = "win" .. j
        if j ~= s.row.index then targets[id] = { window = j } end
        elements[#elements + 1] = rectangle(c.preview.background, geo.preview(j), geo.previewRadius, id)
        local cached = previewOf(entry.id)
        if cached and cached.image then
            for _, element in ipairs({ previewElements(c, cached, geo.fit(j, cached.image:size())) }) do
                elements[#elements + 1] = element
            end
        end
        local title = entry.title ~= "" and entry.title or (app:name() or "")
        elements[#elements + 1] = text(c, title, geo.title(j), c.preview.titleSize)
    end
    canvas:replaceElements(elements)
    return targets
end

return M
