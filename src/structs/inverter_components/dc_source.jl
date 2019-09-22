abstract type DCSource <: InverterComponent end

@def dcsource_ports begin
    state_input = Vector{Symbol}()
    inner_input = Vector{Int64}()
end

mutable struct FixedDCSource <: DCSource
    voltage::Float64
    n_states::Int64
    states::Vector{Symbol}
    ports::Ports

        function FixedDCSource(voltage::Float64)

            @dcsource_ports

            new(voltage,
                0,
                Vector{Symbol}(),
                Ports(state_input, inner_input))
        end
end
