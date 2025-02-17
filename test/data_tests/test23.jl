using PowerSystems
using NLsolve
const PSY = PowerSystems

include(joinpath(dirname(@__FILE__), "dynamic_test_data.jl"))
include(joinpath(dirname(@__FILE__), "data_utils.jl"))
############### Data Network ########################
omib_file_dir = joinpath(dirname(@__FILE__), "OMIB_DARCO_PSR.raw")
omib_sys = System(omib_file_dir, runchecks = false)
add_source_to_ref(omib_sys)

############### Data Dynamic devices ########################
function inv_darco_droop(static_device)
    return PSY.DynamicInverter(
        get_name(static_device),
        1.0, #ω_ref
        converter_low_power(), #converter
        outer_control_droop(), #outercontrol
        inner_control(), #inner_control
        dc_source_lv(),
        no_pll(),
        filt(),
    ) #pss
end

#Attach dynamic generator. Currently use PSS/e format based on bus #.
device = [g for g in get_components(Generator, omib_sys)][1]
case_inv = inv_darco_droop(device)
add_component!(omib_sys, case_inv, device)
