"""
    Saturation function for quadratic saturation models for machines
        Se(x) = B * (x - A)^2 / x
"""
function saturation_function(
    machine::Union{PSY.RoundRotorQuadratic, PSY.SalientPoleQuadratic},
    x::ACCEPTED_REAL_TYPES,
)
    Sat_A, Sat_B = PSY.get_saturation_coeffs(machine)
    return Sat_B * (x - Sat_A)^2 / x
end

"""
    Saturation function for exponential saturation models for machines
        Se(x) = B * x^A
"""
function saturation_function(
    machine::Union{PSY.RoundRotorExponential, PSY.SalientPoleExponential},
    x::ACCEPTED_REAL_TYPES,
)
    Sat_A, Sat_B = PSY.get_saturation_coeffs(machine)
    return Sat_B * x^Sat_A
end

function rectifier_function(I::Float64)
    if I <= 0.0
        return 1.0
    elseif I <= 0.433
        return 1.0 - 0.577 * I
    elseif I < 0.75
        return sqrt(0.75 - I^2)
    elseif I <= 1.0
        return 1.732 * (1.0 - I)
    else
        return 0.0
    end
end

function saturation_function(avr::PSY.ESAC1A, x::ACCEPTED_REAL_TYPES)
    Sat_A, Sat_B = PSY.get_saturation_coeffs(avr)
    return Sat_B * (x - Sat_A)^2 / x
end

function rectifier_function(I::T) where {T <: ACCEPTED_REAL_TYPES}
    if I <= 0.0
        return one(T)
    elseif I <= 0.433
        return 1.0 - 0.577 * I
    elseif I < 0.75
        return sqrt(0.75 - I^2)
    elseif I <= 1.0
        return 1.732 * (1.0 - I)
    else
        return zero(T)
    end
end

function output_pss_limiter(
    V_ss::X,
    V_ct::X,
    V_cl::Float64,
    V_cu::Float64,
) where {X <: ACCEPTED_REAL_TYPES}
    # Bypass limiter block if one limiter parameter is set to zero.
    if V_cl == 0.0 || V_cu == 0.0
        return V_ss
    end
    if V_cl <= V_ct <= V_cl
        return V_ss
    elseif V_ct < V_cl
        return zero(X)
    elseif V_ct > V_cu
        return zero(X)
    else
        error("Logic error in PSS")
    end
end

function deadband_function(
    x::T,
    db_low::Float64,
    db_high::Float64,
) where {T <: ACCEPTED_REAL_TYPES}
    if x > db_high
        return x - db_high
    elseif x < db_low
        return x - db_low
    else
        return zero(T)
    end
end

function current_limit_logic(
    inner_control::PSY.RECurrentControlB,
    ::Type{Base.RefValue{0}}, #PQ_Flag = 0: Q Priority
    Vt_filt::X,
    Ip_cmd::X,
    Iq_cmd::X,
) where {X <: ACCEPTED_REAL_TYPES}
    I_max = PSY.get_I_max(inner_control)
    Iq_max = I_max
    Iq_min = -Iq_max
    Ip_min = 0.0
    local_I = I_max^2 - Iq_cmd^2
    if local_I < 0
        local_I = 0
    else
        local_I = sqrt(local_I)
    end
    if local_I < I_max
        Ip_max = local_I
    else
        Ip_max = I_max
    end
    return Ip_min, Ip_max, Iq_min, Iq_max
end

function current_limit_logic(
    inner_control::PSY.RECurrentControlB,
    ::Type{Base.RefValue{1}}, #PQ_Flag = 1: P Priority
    Vt_filt::X,
    Ip_cmd::X,
    Iq_cmd::X,
) where {X <: ACCEPTED_REAL_TYPES}
    I_max = PSY.get_I_max(inner_control)
    Ip_max = I_max
    Ip_min = 0.0
    local_I = I_max^2 - Ip_cmd^2
    if local_I < 0
        local_I = 0
    else
        local_I = sqrt(local_I)
    end
    if local_I < Iq_max
        Iq_max = local_I
    else
        Iq_max = I_max
    end
    Iq_min = -Iq_max
    return Ip_min, Ip_max, Iq_min, Iq_max
end

function get_LVPL_gain(
    Vmeas::T,
    Zerox::Float64,
    Brkpt::Float64,
    Lvpl1::Float64,
) where {T <: ACCEPTED_REAL_TYPES}
    if Vmeas < Zerox
        return zero(T)
    elseif Vmeas > Brkpt
        return one(T) * Lvpl1
    else
        return Lvpl1 / (Brkpt - Zerox) * (Vmeas - Zerox)
    end
end

function get_LV_current_gain(
    V_t::T,
    Lv_pnt0::Float64,
    Lv_pnt1::Float64,
) where {T <: ACCEPTED_REAL_TYPES}
    if V_t < Lv_pnt0
        return zero(T)
    elseif V_t > Lv_pnt1
        return one(T)
    else
        return 1.0 / (Lv_pnt0 - Lv_pnt1) * (V_t - Lv_pnt0)
    end
end
