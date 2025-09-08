#!/usr/bin/env julia
using ArgParse, CSV, DataFrames, Random

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--L"
            help = "Length of the cutting object (stock roll/bar)"
            arg_type = Int
            required = true
        "--n"
            help = "Number of item types"
            arg_type = Int
            required = true
        "--min_item_len"
            help = "Minimum item length"
            arg_type = Int
            required = true
        "--max_item_len"
            help = "Maximum item length"
            arg_type = Int
            required = true
        "--min_demand"
            help = "Minimum demand"
            arg_type = Int
            required = true
        "--max_demand"
            help = "Maximum demand"
            arg_type = Int
            required = true
        "--filename"
            help = "Output CSV filename"
            arg_type = String
            required = true
    end

    return parse_args(s)
end

function generate_csp_instance(L::Int, n::Int, min_item_len::Int, max_item_len::Int, 
    min_demand::Int, max_demand::Int, filename::String)
    #----- Feasibility check

     if min_item_len > max_item_len
        error("❌ Please, check the item length interval.")
    end

    if min_demand > max_demand
        error("❌ Please, check the demand interval.")
    end

    if min_item_len > L 
        error("❌ Infeasible instance: all item lengths exceed the stock length = $L")
    elseif max_item_len > L
        @warn "⚠️ Some items may exceed the stock length = $L"
    end

    #----- Generate item lengths (bounded by stock length)

    item_lengths = rand(min_item_len:min(max_item_len, L), n)

    #----- Generate item demands

    demands = rand(min_demand:max_demand, n)

    #----- Build the data frame

    df =  DataFrame(Item = 1:n, Length = item_lengths, Demand = demands)

    #----- Save instance

    CSV.write(filename, df)
end

function main()
    #----- Parse command line arguments 

    args = parse_commandline()

    #----- Generate an instance example

    generate_csp_instance(args["L"], args["n"], args["min_item_len"], args["max_item_len"],
    args["min_demand"], args["max_demand"], args["filename"])
end

main()