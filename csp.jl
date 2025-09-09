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

    RMP = Model(optimizer_with_attributes(Gurobi.Optimizer,
    "TimeLimit" => 10.0,
    "OutputFlag" => 0)) 
    P::Int = length(a)

    #----- Decision variables 

    @variable(RMP, X[p in 1:P] >= 0)

    #----- Objective 

    @objective(RMP, Min, sum(X[p] for p in 1:P))

    #----- Constraints 

    @constraint(RMP, demand[i in 1:inst.n], sum(a[p][i] * X[p] for p in 1:P) >= inst.b[i])

    #----- Solve the model 

    optimize!(RMP)

    #----- Check the termination status and extract the duals

    status = termination_status(RMP)

    if status == MOI.OPTIMAL || status == MOI.OPTIMAL_INACCURATE
        duals = [dual(demand[i]) for i in 1:inst.n]
    elseif status == MOI.TIME_LIMIT && has_values(RMP)
        @warn "⏱️ Time limit reached in RMP, using current dual values."
        duals = [dual(demand[i]) for i in 1:inst.n]
    else
        error("❌ Failed to solve the Restricted Master Problem (status = $status)")
    end

    return duals
end

function pricing_problem(inst::Instance, w::Vector{Float64})
    #----- Create and solve the model for the pricing problem (0-1 Knapsack)

    KP = Model(optimizer_with_attributes(Gurobi.Optimizer,
    "TimeLimit" => 60.0,
    "OutputFlag" => 0)) 

    #----- Decision variables

    @variable(KP, a[i in 1:inst.n] >= 0, Int)

    #----- Objective 

    @objective(KP, Max, sum(w[i] * a[i] for i in 1:inst.n))

    #----- Constraints 

    @constraint(KP, sum(inst.I[i] * a[i] for i in 1:inst.n) <= inst.L)

    #----- Solve the model

    optimize!(KP)

    #----- Check the termination status and get the objective

    status = termination_status(KP)

    if status == MOI.OPTIMAL
        zIP = objective_value(KP)
    elseif status == MOI.TIME_LIMIT && has_values(KP)
        @warn "⏱️ Time limit reached in pricing problem, using current solution."
        zIP = objective_value(KP)
    else
        error("❌ Failed to solve the pricing problem (knapsack subproblem).")
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

    #----- Set time counter 

    start_time = time()

    while true
        #----- Update iteration counter 

        iter += 1

        #----- Solve the restricted master problem and get the duals

        w = restricted_master_problem(inst, a)

        #----- Obtain a new pattern after solving the knapsack sub-problem 

        new_pattern, zIP = pricing_problem(inst, w)

        #----- Compute elapsed time 

        elapsed = time() - start_time

        #----- Stop the algorithm if no improving pattern exists

        if 1 - zIP >= 0
            @info "No new patterns, terminating the algorithm after $iter iterations."
            break
        elseif elapsed >= 600
            @info "Terminating the search after $iter iterations and $elapsed seconds."
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