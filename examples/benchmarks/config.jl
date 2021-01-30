using Printf
using TypedTables
using CSV

const MAX_MESSAGE_SIZE = 1<<22
const LARGE_MESSAGE_SIZE = 8192

const LAT_LOOP_SMALL = 10000
const LAT_SKIP_SMALL = 100
const LAT_LOOP_LARGE = 1000
const LAT_SKIP_LARGE = 10

function prettytime(t)
    if t < 1e3
        value, units = t, "ns"
    elseif t < 1e6
        value, units = t / 1e3, "μs"
    elseif t < 1e9
        value, units = t / 1e6, "ms"
    else
        value, units = t / 1e9, "s"
    end
    return string(@sprintf("%.3f", value), " ", units)
end