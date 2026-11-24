local M = {}

local icons = {}

local function iconFor(app)
    local id = app:bundleID()
    if not id then return nil end
    if icons[id] == nil then icons[id] = hs.image.imageFromAppBundle(id) or false end
    return icons[id] or nil
end

local function grow(c, f)
    return { x = f.x - c.highlightInset, y = f.y - c.highlightInset, w = f.w + c.highlightInset * 2, h = f.h + c.highlightInset * 2 }
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

local function fit(box, size)
    local scale = math.min(box.w / size.w, box.h / size.h)
    local w, h = size.w * scale, size.h * scale
    return { x = box.x + (box.w - w) / 2, y = box.y + (box.h - h) / 2, w = w, h = h }
end

local function place(canvas, screen, width, height)
    canvas:frame({
        x = screen.x + (screen.w - width) / 2,
        y = screen.y + (screen.h - height) / 2,
        w = width,
        h = height,
    })
end

local function renderApps(canvas, s, c)
    local inset = c.margin + c.highlightInset
    local count = #s.apps
    local content = count * c.iconSize + (count - 1) * c.gap
    local labelY = inset + c.iconSize + c.highlightInset + c.labelGap
    local function icon(i)
        return { x = inset + (i - 1) * (c.iconSize + c.gap), y = inset, w = c.iconSize, h = c.iconSize }
    end
    place(canvas, s.screen, content + inset * 2, labelY + c.labelHeight + c.margin)

    local elements = {
        rectangle(c.background, nil, c.radius),
        rectangle(c.highlight, grow(c, icon(s.appIndex)), c.radius / 2),
    }
    local targets = {}
    for i, candidate in ipairs(s.apps) do
        local image = iconFor(candidate)
        if image then
            local id = "app" .. i
            if i ~= s.appIndex then targets[id] = { kind = "app", index = i } end
            elements[#elements + 1] = {
                id = id,
                type = "image",
                image = image,
                trackMouseEnterExit = true,
                trackMouseMove = true,
                frame = icon(i),
            }
        end
    end
    local app = s.apps[s.appIndex]
    elements[#elements + 1] = text(c, app:name() or "", { x = inset, y = labelY, w = content, h = c.labelHeight }, c.textSize)
    canvas:replaceElements(elements)
    return targets
end

local function renderWindows(canvas, s, c, previewOf)
    local app = s.apps[s.appIndex]
    local column = s.column
    local count = #column.windows
    local inset = c.margin + c.highlightInset
    local headerH = c.labelHeight + c.sectionGap
    local captionH = c.labelGap + c.labelHeight
    local available = s.screen.h * c.maxScreenShare - inset * 2 - headerH - (count - 1) * c.gap
    local previewH = math.max(1, math.min(c.preview.width * c.preview.aspect, available / count - captionH))
    local previewW = previewH / c.preview.aspect
    local rowH = previewH + captionH
    local top = inset + headerH
    local function preview(j)
        return { x = inset, y = top + (j - 1) * (rowH + c.gap), w = previewW, h = previewH }
    end
    local function card(j)
        local f = preview(j)
        return { x = f.x, y = f.y, w = f.w, h = rowH }
    end
    place(canvas, s.screen, previewW + inset * 2, top + count * rowH + (count - 1) * c.gap + inset)

    local elements = {
        rectangle(c.background, nil, c.radius),
        rectangle(c.highlight, grow(c, card(column.index)), c.radius / 2),
        text(c, app:name() or "", { x = inset, y = inset, w = previewW, h = c.labelHeight }, c.textSize),
    }
    local targets = {}
    for j, entry in ipairs(column.windows) do
        local id = "win" .. j
        if j ~= column.index then targets[id] = { kind = "window", index = j } end
        local frame = preview(j)
        elements[#elements + 1] = rectangle(c.preview.background, frame, c.radius / 3)
        local cached = previewOf(entry.id)
        if cached and cached.image then
            for _, element in ipairs({ previewElements(c, cached, fit(frame, cached.image:size())) }) do
                elements[#elements + 1] = element
            end
        end
        local title = entry.title ~= "" and entry.title or (app:name() or "")
        local caption = { x = frame.x, y = frame.y + frame.h + c.labelGap, w = frame.w, h = c.labelHeight }
        elements[#elements + 1] = text(c, title, caption, c.preview.titleSize)
        elements[#elements + 1] = rectangle({ white = 0, alpha = 0 }, card(j), c.radius / 3, id)
    end
    canvas:replaceElements(elements)
    return targets
end

function M.render(canvas, s, c, previewOf)
    if s.column then return renderWindows(canvas, s, c, previewOf) end
    return renderApps(canvas, s, c)
end

return M
