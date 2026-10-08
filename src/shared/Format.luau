--!strict
-- Short number formatting for the UI: 1500 -> "1.5K", 2000000 -> "2M".

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local Format = {}

function Format.number(value: number): string
	local n = math.floor(value)
	if n < 1000 then
		return tostring(n)
	end

	local index = 1
	local scaled: number = n
	while scaled >= 1000 and index < #SUFFIXES do
		scaled /= 1000
		index += 1
	end

	-- Round down so 999,999 shows as "999.9K" rather than "1000K".
	local text = string.format("%.1f", math.floor(scaled * 10) / 10)
	text = (string.gsub(text, "%.0$", ""))
	return text .. SUFFIXES[index]
end

function Format.money(value: number): string
	return "$" .. Format.number(value)
end

return Format
