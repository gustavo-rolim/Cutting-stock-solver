#!/usr/bin/env julia
using ArgParse, CSV, DataFrames, Gurobi, JuMP, Plots

struct Instance
    L::Int # Object length
    n::Int # Number of items
    I::Vector{Int} # Items' lengths
    b::Vector{Int} # Items' demand 

    #----- Define a constructor 

    function Instance(L::Integer, n::Integer, I::Vector{<:Integer}, b::Vector{<:Integer})
        @assert L > 0 # The object must have non-negative length
        @assert n > 0 # The number of items must be non-negative
        @assert all(>=(0), I) # All items must have a non-negative length
        @assert length(I) == n && length(b) == n # Each item should have a corresponding demand 
        new(Int(L), Int(n), Int.(I), Int.(b))
    end
end

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--filename", "-f"
            help = "Path to the CSP instance .csv file"
            arg_type = String
            required = true
    end

    args = parse_args(s)

    return args["filename"]
end

function read_instance(filename::String)
    df = CSV.read(filename, DataFrame)

    # Extract L (stock length) from the first row (same for all rows)
    L = Int(df.StockLength[1])

    # Extract number of items
    n = nrow(df)

    # Extract lengths and demands
    I = Vector{Int}(df.Length)
    b = Vector{Int}(df.Demand)

    return Instance(L, n, I, b)
end

function initial_patterns(inst::Instance)
    #----- Generate initial set of feasible patterns

    a = Vector{Int}[]

    for i in 1:inst.n
        pattern = zeros(Int, inst.n)
        pattern[i] = floor(inst.L/inst.I[i])
        push!(a, pattern)
    end

    return a
end

function restricted_master_problem(inst::Instance, a::Vector{Vector{Int}})
    #----- Create and solve the model for the restricted master problem 

    RMP = Model(optimizer_with_attributes(Gurobi.Optimizer)) # Create the model
    P::Int = length(a)

    #----- Decision variables 

    @variable(RMP, X[p in 1:P] >= 0)

    #----- Objective 

    @objective(RMP, Min, sum(X[p] for p in 1:P))

    #----- Constraints 

    @constraint(RMP, demand[i in 1:inst.n], sum(a[p][i] * X[p] for p in 1:P) >= inst.b[i])

    #----- Solve the model 

    optimize!(RMP)

    #----- Check the termination status
    
    if termination_status(RMP) != MOI.OPTIMAL
        error("Failed to solve the Restricted Master Problem (RMP)")
    end

    # Extract duals from RMP

    duals = [dual(demand[i]) for i in 1:inst.n]

    return duals
end

function sub_problem(inst::Instance, w::Vector{Float64})
    #----- Create and solve the model for the sub-problem (knapsack problem)

    KP = Model(optimizer_with_attributes(Gurobi.Optimizer)) # Create the model

    #----- Decision variables

    @variable(KP, a[i in 1:inst.n] >= 0, Int)

    #----- Objective 

    @objective(KP, Max, sum(w[i] * a[i] for i in 1:inst.n))

    #----- Constraints 

    @constraint(KP, sum(inst.I[i] * a[i] for i in 1:inst.n) <= inst.L)

    #----- Solve the model

    optimize!(KP)

    #----- Check the termination status and get the objective 

    if termination_status(KP) == MOI.OPTIMAL
        zIP = objective_value(KP)
    elseif termination_status(KP) == MOI.TIME_LIMIT && has_values(KP)
        zIP = objective_value(KP)
    else
        error("Failed to solve the sub-problem")
    end

    new_pattern = round.(Int, value.(a))

    return new_pattern, zIP 
end

function cutting_locations(inst::Instance, pattern::Vector{Int})
    #----- Compute the cut locations along the stock roll for a given pattern

    locations = Int[]
    offset = 0.0

    for i in 1:inst.n
        for _ in 1:pattern[i]
            offset += inst.I[i]
            push!(locations, offset)
        end
    end

    return locations
end

function plot_patterns(inst::Instance, patterns::Vector{Vector{Int}})
    #----- Initialize the plot for visualizing cutting patterns

    plot = Plots.bar(
        xlims = (0, length(patterns) + 1),
        ylims = (0, inst.L),
        xlabel = "Pattern",
        ylabel = "Pattern length",
        legend = false
    )

    #----- Add each cutting pattern to the plot

    for (i, p) in enumerate(patterns)
        locations = cutting_locations(inst, p)
        Plots.bar!(
            plot,
            fill(i, length(locations)),      # x-axis: pattern index
            reverse(locations);              # y-axis: cut positions
            bar_width = 0.6,
            color = "#90caf9"
        )
    end

    return plot
end

function main_csp()
    #----- Command line aruguments 
    
    filename = parse_commandline()

    #----- Read the problem instance

    inst = read_instance(filename)

    #----- Generate a small set of feasible cutting patterns 

    a = initial_patterns(inst)

    #----- Set an iteration counter

    iter::Int = 0

    while true
        #----- Update iteration counter 

        iter += 1

        #----- Solve the restricted master problem and get the duals

        w = restricted_master_problem(inst, a)

        #----- Obtain a new pattern after solving the knapsack sub-problem 

        new_pattern, zIP = sub_problem(inst, w)

        #----- Stop the algorithm if no improving pattern exists

        if 1 - zIP >= 0
            @info "No new patterns, terminating the algorithm after $iter iterations."
            break
        else
            push!(a, new_pattern)
        end
    end

    #----- Plot the generated patterns

    plt = plot_patterns(inst, a)
    savefig(plt, "cutting_patterns.png")
end

main_csp()