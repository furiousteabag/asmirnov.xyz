function Meta(meta)
  if meta.date then
    local format = "(%d+)-(%d+)-(%d+)"
    local date_string = pandoc.utils.stringify(meta.date)
    local y, m, d = date_string:match(format)
    if y and m and d then
      local date = os.time({
        year = y,
        month = m,
        day = d,
      })
      local formatted_date_string = os.date("%d %b %Y", date)
      meta.date = pandoc.Str(formatted_date_string)
    else
      io.stderr:write("Error: Date format is incorrect or missing. Expected format: YYYY-MM-DD, got: " .. date_string .. "\n")
    end
  else
    io.stderr:write("Error: Date metadata is missing.\n")
  end
  return meta
end
