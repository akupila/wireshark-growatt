local protocol = Proto("growatt", "Growatt Protocol")

local f = {
  -- Header fields
  message_id = ProtoField.uint16("growatt.message_id", "Message ID"),
  protocol_id = ProtoField.uint16("growatt.protocol_id", "Protocol ID"),
  unit_id = ProtoField.uint8("growatt.unit_id", "Unit ID"),
  packet_type = ProtoField.uint8("growatt.packet_type", "Packet Type", base.HEX),

  -- Data fields
  serial = ProtoField.string("growatt.serial", "Datalogger serial"),
  inverter = ProtoField.string("growatt.inverter", "Inverter serial"),
  timestamp = ProtoField.string("growatt.timestamp", "Payload timestamp"),
  status = ProtoField.bool("growatt.status", "Status"),
  ppv = ProtoField.float("growatt.input_power", "Input power"),
  vpv1 = ProtoField.float("growatt.vpv1", "PV1 Voltage"),
  ipv1 = ProtoField.float("growatt.vpv1", "PV1 Current"),
  ppv1 = ProtoField.float("growatt.vpv2", "PV2 Power"),
  vpv2 = ProtoField.float("growatt.vpv2", "PV2 Voltage"),
  ipv2 = ProtoField.float("growatt.vpv2", "PV2 Current"),
  ppv2 = ProtoField.float("growatt.vpv2", "PV2 Power"),
  vpv3 = ProtoField.float("growatt.vpv3", "PV3 Voltage"),
  ipv3 = ProtoField.float("growatt.vpv3", "PV3 Current"),
  ppv3 = ProtoField.float("growatt.vpv3", "PV3 Power"),
  vpv4 = ProtoField.float("growatt.vpv4", "PV4 Voltage"),
  ipv4 = ProtoField.float("growatt.vpv4", "PV4 Current"),
  ppv4 = ProtoField.float("growatt.vpv4", "PV4 Power"),
  pac = ProtoField.float("growatt.pac", "Output power"),
  fac = ProtoField.float("growatt.fac", "Grid frequency"),
  vac1 = ProtoField.float("growatt.vac1", "AC1 Voltage"),
  iac1 = ProtoField.float("growatt.iac1", "AC1 Current"),
  pac1 = ProtoField.float("growatt.pac1", "AC1 Power"),
  vac2 = ProtoField.float("growatt.vac2", "AC2 Voltage"),
  iac2 = ProtoField.float("growatt.iac2", "AC2 Current"),
  pac2 = ProtoField.float("growatt.pac2", "AC2 Power"),
  vac3 = ProtoField.float("growatt.vac3", "AC3 Voltage"),
  iac3 = ProtoField.float("growatt.iac3", "AC3 Current"),
  pac3 = ProtoField.float("growatt.pac3", "AC3 Power"),
  eac_today = ProtoField.float("growatt.eac_today", "Generated today"),
  eac_total = ProtoField.float("growatt.eac_total", "Generated total"),
  total_work = ProtoField.float("growatt.total_work", "Total work time"),
  pviso = ProtoField.uint16("growatt.pv_iso", "PV resistance"),
  rated_power = ProtoField.float("growatt.rated_power", "Rated power"),
}

protocol.fields = f

local function unscramble(data)
  local key = "Growatt"
  local out = {}
  for i = 0, data:len() - 1 do
    local nthData = data(i, 1):uint()
    local nthKey = key:byte(i % #key + 1)
    local v = bit32.bxor(nthData, nthKey)
    out[i + 1] = string.format("%02x", v)
  end
  return ByteArray.new(table.concat(out)):tvb()
end

local function add_float(subtree, field, buf, div, unit)
  subtree:add(field, buf, buf:uint() / div):append_text(unit)
end

-- Define the dissector function
function protocol.dissector(buf, pinfo, tree)
  if buf:len() == 0 then return end

  pinfo.cols.protocol = "Growatt"

  local subtree = tree:add(protocol, buf(), "Growatt Protocol data")
  subtree:add(f.message_id, buf(0, 2))
  subtree:add(f.protocol_id, buf(2, 2))
  subtree:add(f.unit_id, buf(6, 1))
  subtree:add(f.packet_type, buf(7, 1))

  local body = unscramble(buf(8))

  local type = buf(7, 1):uint()
  if type == 0x16 then
    pinfo.cols.info = "Ping"
    subtree:add(body(0, 10), string.format("Serial: %s", body(0, 10):string()))
  elseif type == 0x04 or type == 0x50 then
    if type == 0x04 then
      pinfo.cols.info = "Data"
    elseif type == 0x50 then
      pinfo.cols.info = "Buffered Data"
    end

    subtree:add(f.serial, body(0, 10))
    subtree:add(f.inverter, body(30, 10))

    local year = body(60, 1):uint() + 2000
    local month = body(61, 1):uint()
    local day = body(62, 1):uint()
    local hour = body(63, 1):uint()
    local minute = body(64, 1):uint()
    local second = body(65, 1):uint()
    subtree:add(f.timestamp, body(60, 6)):set_text(
      string.format("Timestamp: %04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour,
        minute, second)
    )

    local statusVal = body(71, 2)
    subtree:add(f.status, statusVal):set_text(
      string.format("Status: %s", statusVal:uint() > 0 and "On" or "Off")
    )
    add_float(subtree, f.ppv, body(73, 4), 10, "W")

    add_float(subtree, f.vpv1, body(77, 2), 10, "V")
    add_float(subtree, f.ipv1, body(79, 2), 10, "A")
    add_float(subtree, f.ppv1, body(81, 4), 10, "W")
    add_float(subtree, f.vpv2, body(85, 2), 10, "V")
    add_float(subtree, f.ipv2, body(87, 2), 10, "A")
    add_float(subtree, f.ppv2, body(89, 4), 10, "W")
    add_float(subtree, f.vpv3, body(93, 2), 10, "V")
    add_float(subtree, f.ipv3, body(95, 2), 10, "A")
    add_float(subtree, f.ppv3, body(97, 4), 10, "W")
    add_float(subtree, f.vpv4, body(101, 2), 10, "V")
    add_float(subtree, f.ipv4, body(103, 2), 10, "A")
    add_float(subtree, f.ppv4, body(105, 4), 10, "W")

    add_float(subtree, f.pac, body(117, 4), 10, "W")
    add_float(subtree, f.fac, body(121, 2), 100, "Hz")

    add_float(subtree, f.vac1, body(123, 2), 10, "V")
    add_float(subtree, f.iac1, body(125, 2), 10, "A")
    add_float(subtree, f.pac1, body(127, 4), 10, "W")
    add_float(subtree, f.vac2, body(131, 2), 10, "V")
    add_float(subtree, f.iac2, body(133, 2), 10, "A")
    add_float(subtree, f.pac2, body(135, 4), 10, "W")
    add_float(subtree, f.vac3, body(139, 2), 10, "V")
    add_float(subtree, f.iac3, body(141, 2), 10, "A")
    add_float(subtree, f.pac3, body(143, 4), 10, "W")

    add_float(subtree, f.eac_today, body(169, 4), 10, "kWh")
    add_float(subtree, f.eac_total, body(173, 4), 10, "kWh")
    add_float(subtree, f.total_work, body(177, 4), 2, "h")

    subtree:add(f.pviso, body(245, 2)):append_text("K ohm")
    add_float(subtree, f.rated_power, body(277, 2), 10, "W")
  end
end

-- Register the dissector
local tcp_table = DissectorTable.get("tcp.port")
tcp_table:add(5279, protocol)
