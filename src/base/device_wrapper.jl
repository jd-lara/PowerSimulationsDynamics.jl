get_inner_vars_count(::PSY.DynamicGenerator) = GEN_INNER_VARS_SIZE
get_inner_vars_count(::PSY.DynamicInverter) = INV_INNER_VARS_SIZE
get_inner_vars_count(::PSY.PeriodicVariableSource) = 0

index(::Type{<:PSY.TurbineGov}) = 1
index(::Type{<:PSY.PSS}) = 2
index(::Type{<:PSY.Machine}) = 3
index(::Type{<:PSY.Shaft}) = 4
index(::Type{<:PSY.AVR}) = 5

index(::Type{<:PSY.DCSource}) = 1
index(::Type{<:PSY.FrequencyEstimator}) = 2
index(::Type{<:PSY.OuterControl}) = 3
index(::Type{<:PSY.InnerControl}) = 4
index(::Type{<:PSY.Converter}) = 5
index(::Type{<:PSY.Filter}) = 6

"""
Wraps DynamicInjection devices from PowerSystems to handle changes in controls and connection
status, and allocate the required indexes of the state space.
"""
struct DynamicWrapper{T <: PSY.DynamicInjection}
    device::T
    system_base_power::Float64
    system_base_frequency::Float64
    static_type::Type{<:PSY.StaticInjection}
    bus_category::Type{<:BusCategory}
    connection_status::Base.RefValue{Float64}
    V_ref::Base.RefValue{Float64}
    ω_ref::Base.RefValue{Float64}
    P_ref::Base.RefValue{Float64}
    Q_ref::Base.RefValue{Float64}
    inner_vars_index::Vector{Int}
    ix_range::Vector{Int}
    ode_range::Vector{Int}
    bus_ix::Int
    global_index::Base.ImmutableDict{Symbol, Int}
    component_state_mapping::Base.ImmutableDict{Int, Vector{Int}}
    input_port_mapping::Base.ImmutableDict{Int, Vector{Int}}
end

function DynamicWrapper(
    device::T,
    bus_ix::Int,
    ix_range,
    ode_range,
    inner_var_range,
    sys_base_power,
    sys_base_freq,
) where {T <: PSY.Device}
    dynamic_device = PSY.get_dynamic_injector(device)
    @assert dynamic_device !== nothing
    device_states = PSY.get_states(dynamic_device)
    component_state_mapping = Dict{Int, Vector{Int}}()
    input_port_mapping = Dict{Int, Vector{Int}}()

    for c in PSY.get_dynamic_components(dynamic_device)
        ix = index(typeof(c))
        component_state_mapping[ix] = _index_local_states(c, device_states)
        input_port_mapping[ix] = _index_port_mapping!(c, device_states)
    end

    return DynamicWrapper{typeof(dynamic_device)}(
        dynamic_device,
        sys_base_power,
        sys_base_freq,
        T,
        BUS_MAP[PSY.get_bustype(PSY.get_bus(device))],
        Base.Ref(1.0),
        Base.Ref(PSY.get_V_ref(dynamic_device)),
        Base.Ref(PSY.get_ω_ref(dynamic_device)),
        Base.Ref(PSY.get_P_ref(dynamic_device)),
        Base.Ref(PSY.get_reactive_power(device)),
        inner_var_range,
        ix_range,
        ode_range,
        bus_ix,
        Base.ImmutableDict(
            sort!(device_states .=> ix_range, by = x -> x.second, rev = true)...,
        ),
        Base.ImmutableDict(component_state_mapping...),
        Base.ImmutableDict(input_port_mapping...),
    )
end

function DynamicWrapper(
    device::PSY.Source,
    bus_ix::Int,
    ix_range,
    ode_range,
    inner_var_range,
    sys_base_power,
    sys_base_freq,
)
    dynamic_device = PSY.get_dynamic_injector(device)
    @assert dynamic_device !== nothing
    device_states = PSY.get_states(dynamic_device)
    @assert PSY.get_X_th(dynamic_device) == PSY.get_X_th(device)
    @assert PSY.get_R_th(dynamic_device) == PSY.get_R_th(device)

    return DynamicWrapper{typeof(dynamic_device)}(
        dynamic_device,
        sys_base_power,
        sys_base_freq,
        PSY.Source,
        BUS_MAP[PSY.get_bustype(PSY.get_bus(device))],
        Base.Ref(1.0),
        Base.Ref(0.0),
        Base.Ref(0.0),
        Base.Ref(0.0),
        Base.Ref(0.0),
        collect(inner_var_range),
        collect(ix_range),
        collect(ode_range),
        bus_ix,
        Base.ImmutableDict(Dict(device_states .=> ix_range)...),
        Base.ImmutableDict{Int, Vector{Int}}(),
        Base.ImmutableDict{Int, Vector{Int}}(),
    )
end

function _index_local_states(component::PSY.DynamicComponent, device_states::Vector{Symbol})
    component_state_index = Vector{Int}(undef, PSY.get_n_states(component))
    component_states = PSY.get_states(component)
    for (ix, s) in enumerate(component_states)
        component_state_index[ix] = findfirst(x -> x == s, device_states)
    end
    return component_state_index
end

function _index_port_mapping!(
    component::PSY.DynamicComponent,
    device_states::Vector{Symbol},
)
    ports = Ports(component)
    index_component_inputs = Vector{Int}()
    for i in ports[:states]
        tmp = [(ix, var) for (ix, var) in enumerate(device_states) if var == i]
        isempty(tmp) && continue
        push!(index_component_inputs, tmp[1][1])
    end
    return index_component_inputs
end

get_device(wrapper::DynamicWrapper) = wrapper.device
get_device_type(::DynamicWrapper{T}) where {T <: PSY.DynamicInjection} = T
get_bus_category(wrapper::DynamicWrapper) = wrapper.bus_category
get_inner_vars_index(wrapper::DynamicWrapper) = wrapper.inner_vars_index
get_ix_range(wrapper::DynamicWrapper) = wrapper.ix_range
get_ode_ouput_range(wrapper::DynamicWrapper) = wrapper.ode_range
get_bus_ix(wrapper::DynamicWrapper) = wrapper.bus_ix
get_global_index(wrapper::DynamicWrapper) = wrapper.global_index
get_component_state_mapping(wrapper::DynamicWrapper) = wrapper.component_state_mapping
get_input_port_mapping(wrapper::DynamicWrapper) = wrapper.input_port_mapping

get_system_base_power(wrapper::DynamicWrapper) = wrapper.system_base_power
get_system_base_frequency(wrapper::DynamicWrapper) = wrapper.system_base_frequency

get_P_ref(wrapper::DynamicWrapper) = wrapper.P_ref[]
get_Q_ref(wrapper::DynamicWrapper) = wrapper.Q_ref[]
get_V_ref(wrapper::DynamicWrapper) = wrapper.V_ref[]
get_ω_ref(wrapper::DynamicWrapper) = wrapper.ω_ref[]

set_P_ref(wrapper::DynamicWrapper, val::Float64) = wrapper.P_ref[] = val
set_Q_ref(wrapper::DynamicWrapper, val::Float64) = wrapper.Q_ref[] = val
set_V_ref(wrapper::DynamicWrapper, val::Float64) = wrapper.V_ref[] = val
set_ω_ref(wrapper::DynamicWrapper, val::Float64) = wrapper.ω_ref[] = val

# PSY overloads for the wrapper
PSY.get_name(wrapper::DynamicWrapper) = PSY.get_name(wrapper.device)
PSY.get_ext(wrapper::DynamicWrapper) = PSY.get_ext(wrapper.device)
PSY.get_states(wrapper::DynamicWrapper) = PSY.get_states(wrapper.device)
PSY.get_n_states(wrapper::DynamicWrapper) = PSY.get_n_states(wrapper.device)
PSY.get_base_power(wrapper::DynamicWrapper) = PSY.get_base_power(wrapper.device)

PSY.get_machine(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicGenerator} =
    wrapper.device.machine
PSY.get_shaft(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicGenerator} =
    wrapper.device.shaft
PSY.get_avr(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicGenerator} =
    wrapper.device.avr
PSY.get_prime_mover(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicGenerator} =
    wrapper.device.prime_mover
PSY.get_pss(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicGenerator} =
    wrapper.device.pss

PSY.get_converter(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicInverter} =
    wrapper.device.converter
PSY.get_outer_control(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicInverter} =
    wrapper.device.outer_control
PSY.get_inner_control(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicInverter} =
    wrapper.device.inner_control
PSY.get_dc_source(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicInverter} =
    wrapper.device.dc_source
PSY.get_freq_estimator(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicInverter} =
    wrapper.device.freq_estimator
PSY.get_filter(wrapper::DynamicWrapper{T}) where {T <: PSY.DynamicInverter} =
    wrapper.device.filter

function get_local_state_ix(
    wrapper::DynamicWrapper,
    ::Type{T},
) where {T <: PSY.DynamicComponent}
    return wrapper.component_state_mapping[index(T)]
end

function get_input_port_ix(
    wrapper::DynamicWrapper,
    ::Type{T},
) where {T <: PSY.DynamicComponent}
    return wrapper.input_port_mapping[index(T)]
end

function get_local_state_ix(wrapper::DynamicWrapper, ::T) where {T <: PSY.DynamicComponent}
    return get_local_state_ix(wrapper, T)
end

function get_input_port_ix(wrapper::DynamicWrapper, ::T) where {T <: PSY.DynamicComponent}
    return get_input_port_ix(wrapper, T)
end

struct StaticWrapper{T <: PSY.StaticInjection, V}
    device::T
    connection_status::Base.RefValue{Float64}
    V_ref::Base.RefValue{Float64}
    θ_ref::Base.RefValue{Float64}
    P_ref::Base.RefValue{Float64}
    Q_ref::Base.RefValue{Float64}
    bus_ix::Int
end

function DynamicWrapper(device::T, bus_ix::Int) where {T <: PSY.Device}
    bus = PSY.get_bus(device)
    StaticWrapper{T, BUS_MAP[PSY.get_bustype(bus)]}(
        device,
        Base.Ref(1.0),
        Base.Ref(PSY.get_magnitude(bus)),
        Base.Ref(PSY.get_angle(bus)),
        Base.Ref(PSY.get_active_power(device)),
        Base.Ref(PSY.get_reactive_power(device)),
        bus_ix,
    )
end

function StaticWrapper(device::T, bus_ix::Int) where {T <: PSY.Source}
    bus = PSY.get_bus(device)
    return StaticWrapper{T, BUS_MAP[PSY.get_bustype(bus)]}(
        device,
        Base.Ref(1.0),
        Base.Ref(PSY.get_internal_voltage(device)),
        Base.Ref(PSY.get_internal_angle(device)),
        Base.Ref(PSY.get_active_power(device)),
        Base.Ref(PSY.get_reactive_power(device)),
        bus_ix,
    )
end

# get_bustype is already exported in PSY. So this is named this way to avoid name collisions
get_bus_category(::StaticWrapper{<:PSY.StaticInjection, U}) where {U} = U

function StaticWrapper(device::T, bus_ix::Int) where {T <: PSY.ElectricLoad}
    bus = PSY.get_bus(device)
    return StaticWrapper{T, LOAD_MAP[PSY.get_model(device)]}(
        device,
        Base.Ref(1.0),
        Base.Ref(PSY.get_magnitude(bus)),
        Base.Ref(PSY.get_angle(bus)),
        Base.Ref(PSY.get_active_power(device)),
        Base.Ref(PSY.get_reactive_power(device)),
        bus_ix,
    )
end

# TODO: something smart to forward fields
get_device(wrapper::StaticWrapper) = wrapper.device
get_bus_ix(wrapper::StaticWrapper) = wrapper.bus_ix

# get_bustype is already exported in PSY. So this is named this way to avoid name collisions
get_bus_category(::StaticWrapper{<:PSY.ElectricLoad, U}) where {U} = PQBus
get_load_category(::StaticWrapper{<:PSY.ElectricLoad, U}) where {U} = U

get_P_ref(wrapper::StaticWrapper) = wrapper.P_ref[]
get_Q_ref(wrapper::StaticWrapper) = wrapper.Q_ref[]
get_V_ref(wrapper::StaticWrapper) = wrapper.V_ref[]
get_θ_ref(wrapper::StaticWrapper) = wrapper.θ_ref[]

set_P_ref(wrapper::StaticWrapper, val::Float64) = wrapper.P_ref[] = val
set_Q_ref(wrapper::StaticWrapper, val::Float64) = wrapper.Q_ref[] = val
set_V_ref(wrapper::StaticWrapper, val::Float64) = wrapper.V_ref[] = val
set_θ_ref(wrapper::StaticWrapper, val::Float64) = wrapper.θ_ref[] = val

PSY.get_bus(wrapper::StaticWrapper) = PSY.get_bus(wrapper.device)
PSY.get_active_power(wrapper::StaticWrapper) = PSY.get_active_power(wrapper.device)
PSY.get_reactive_power(wrapper::StaticWrapper) = PSY.get_reactive_power(wrapper.device)
PSY.get_name(wrapper::StaticWrapper) = PSY.get_name(wrapper.device)
PSY.get_ext(wrapper::StaticWrapper) = PSY.get_ext(wrapper.device)

function set_connection_status(wrapper::Union{StaticWrapper, DynamicWrapper}, val::Int)
    if val == 0
        @debug "Generator $(PSY.get_name(wrapper)) status set to off"
    elseif val == 1
        @debug "Generator $(PSY.get_name(wrapper)) status set to on"
    else
        error("Invalid status $val. It can only take values 1 or 0")
    end
    wrapper.connection_status[] = Float64(val)
end

get_connection_status(wrapper::Union{StaticWrapper, DynamicWrapper}) =
    wrapper.connection_status[]
