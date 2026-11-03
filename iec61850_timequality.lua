-- Получить существующий протокол GOOSE
local goose_tq_proto = Proto("goose_tq", "GOOSE TimeQuality Decoder")

-- Создать поля для доступа к данным GOOSE
local goose_t_field = Field.new("goose.t")

-- Функция декодирования байта TimeQuality
local function decode_timequality(tvb, pinfo, tree)
    -- Проверяем наличие поля goose.t
    local goose_t = goose_t_field()
    if not goose_t then return end
    
    -- Получаем диапазон байтов поля (не value, а range!)
    local ts_range = goose_t.range
    if not ts_range or ts_range:len() < 8 then return end
    
    -- Последний (8-й) байт — TimeQuality (индекс 7, т.к. нумерация с 0)
    local tq_byte = ts_range(7, 1):uint()
    
    -- Добавляем поддерево в протокол GOOSE
    local tq_tree = tree:add(goose_tq_proto, ts_range(7, 1), 
        string.format("TimeQuality: 0x%02X", tq_byte))
    
    -- Расшифровка отдельных битов
    local leap      = bit.rshift(bit.band(tq_byte, 0x80), 7)
    local failure   = bit.rshift(bit.band(tq_byte, 0x40), 6)
    local not_sync  = bit.rshift(bit.band(tq_byte, 0x20), 5)
    local accuracy  = bit.band(tq_byte, 0x1F)
    
    tq_tree:add(string.format("LeapSecondsKnown:      %s", leap == 1 and "True" or "False"))
    tq_tree:add(string.format("ClockFailure:          %s", failure == 1 and "True " or "False"))
    tq_tree:add(string.format("ClockNotSynchronized:  %s", not_sync == 1 and "True" or "False"))
    tq_tree:add(string.format("TimeAccuracy (bits 0-4): %d", accuracy))
    
    -- Добавим текстовое описание в колонку Info
    if not_sync == 1 then
        pinfo.cols.info:append(" [CLK NOT SYNC]")
    elseif failure == 1 then
        pinfo.cols.info:append(" [CLK FAILURE]")
    end
end

-- Регистрируем post-dissector
register_postdissector(goose_tq_proto)

function goose_tq_proto.dissector(tvb, pinfo, tree)
    decode_timequality(tvb, pinfo, tree)
end