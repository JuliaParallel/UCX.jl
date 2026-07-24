# Defined here rather than in the prologue because it uses `ucs_status_t`, which
# is defined after the prologue.
struct UCXException <: Exception
    status::ucs_status_t
end
