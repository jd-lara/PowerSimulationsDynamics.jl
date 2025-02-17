@testset "Test 32 9-Bus Machine Onlu System" begin
    path = (joinpath(pwd(), "test-9Bus-system"))
    !isdir(path) && mkdir(path)
    try
        sys = System(joinpath(TEST_FILES_DIR, "data_tests/9BusSystem.json"))

        gen_static = get_component(ThermalStandard, sys, "generator-2-1")
        gen_dynamic = get_dynamic_injector(gen_static)
        sim = Simulation(
            ResidualModel,
            sys,
            path,
            (0.0, 2.0),
            ControlReferenceChange(1.0, gen_dynamic, :P_ref, 0.78),
        )
        small_sig = small_signal_analysis(sim)
        @test execute!(sim, IDA()) == PSID.SIMULATION_FINALIZED

        sim = Simulation(
            MassMatrixModel,
            sys,
            path,
            (0.0, 2.0),
            ControlReferenceChange(1.0, gen_dynamic, :P_ref, 0.78),
        )
        small_sig = small_signal_analysis(sim)
        @test execute!(sim, Rodas4()) == PSID.SIMULATION_FINALIZED

    finally
        @info("removing test files")
        rm(path, force = true, recursive = true)
    end
end
