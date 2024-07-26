function Meta(meta)
  if meta.date then
    local format = "(%d+)-(%d+)-(%d+)"
    local y, m, d = pandoc.utils.stringify(meta.date):match(format)
    local date = os.time({
      year = y,
      month = m,
      day = d,
    })
    local date_string = os.date("%d %b %Y", date)
    meta.date = pandoc.Str(date_string)
    return meta
  end
end
