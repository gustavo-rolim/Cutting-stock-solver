using JuMP, Gurobi

struct Instance
    L::Int32 # Object length
    n::Int32 # Number of items
    I::Vector{Int32} # Items' lengths
    b::Vector{Int32} # Items' demand 

    #----- Define a constructor 

    function Instance(L::Integer, n::Integer, I::Vector{<:Integer}, b::Vector{<:Integer})
        @assert L > 0 # The object must have non-negative length
        @assert n > 0 # The number of items must be non-negative
        @assert all(>=(0), I) # All items must have a non-negative length
        @assert length(I) == n && length(b) == n # Each item should have a corresponding demand 
        new(Int32(L), Int32(n), Int32.(I), Int32.(b))
    end
end

function initial_patterns(inst::Instance)
    #----- Generate initial set of feasible patterns

    a = Vector{Int32}[]

    for i::Int32 in 1:inst.n
        pattern = zeros(Int32, inst.n)
        pattern[i] = floor(inst.L/inst.I[i])
        push!(a, pattern)
    end

    return a
end

function restricted_master_problem(inst::Instance, a::Vector{Vector{Int32}})
    #----- Create and solve the model for the restricted master problem 

    time_limit::Int32 = 10 # Set a time limit for the solver
    RMP = Model(optimizer_with_attributes(Gurobi.Optimizer, "TimeLimit" => time_limit)) # Create the model
    P::Int32 = length(a)

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

    time_limit::Int32 = 10 # Set a time limit for the solver
    KP = Model(optimizer_with_attributes(Gurobi.Optimizer, "TimeLimit" => time_limit)) # Create the model

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

    new_pattern = round.(Int32, value.(a))

    return new_pattern, zIP 
end

function main_csp()
    #----- Problem Input 
    
    inst = Instance(40, 6, [4, 2, 6, 7, 8, 12], [20, 41, 23, 12, 9, 34])

    #----- Generate a small set of feasible cutting patterns 

    a = initial_patterns(inst)

    #----- Set an iteration counter

    iter::Int32 = 0

    while true
        #----- Update iteration counter 

        iter += 1

        #----- Solve the restricted master problem and get the duals

        w = restricted_master_problem(inst, a)

        #----- Obtain a new pattern after solving the knapsack sub-problem 

        new_pattern, zIP = sub_problem(inst, w)

        #----- Check the stopping condition 

        if 1 - zIP >= 0
            break
        else
            push!(a, new_pattern)
        end
    end

    println(a)
end

main_csp()