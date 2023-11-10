function Header (header)
    local id = header.identifier
    if id ~= "" then
        local link = pandoc.Link(header.content, '#' .. id)
        link.attributes['style'] = 'text-decoration: none; color: inherit;'
        return pandoc.Header(header.level, link, id)
    end
end
