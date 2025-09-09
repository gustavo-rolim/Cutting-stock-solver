# Cutting stock solver

The solver consists of two main scripts:

1. **`gen.jl`** — Generates a random CSP instance and saves it as a `.csv` file.  
   - An example file, **`example.csv`**, is included to illustrate the expected CSV format.  
   - This file can be used directly to test the solver.

2. **`csp.jl`** — Reads a `.csv` instance and solves it using column generation.  
   - Produces a plot of the cutting patterns found.  
   - Implements stopping criteria based on a **global time limit** and solver-specific limits:  
     - Maximum wall-clock time: **600 seconds**.  
     - Restricted Master Problem (RMP): **10 seconds per solve**.  
     - Pricing Problem (0-1 Knapsack): **60 seconds per solve**.

## Usage 

### Generate an instance 

1. Run the generator with the following syntax, e.g.:
```bash
julia gen.jl --L 20 --n 5 --min_item_len 2 --max_item_len 7 --min_demand 1 --max_demand 5 --filename example.csv
```
2. Alternatively, use the provided **`example.csv`** file.

### Solve the instance

1. Run the solver by passing the filename as an argument:
```bash
julia csp.jl --filename example.csv
```

## Output example

The solver saves a `.png` file with a bar chart illustrating the generated cutting patterns.

## Requirements 

- Julia 1.11
- The following Julia packages:
  - [`JuMP`](https://jump.dev/JuMP.jl/stable/) — modeling language for mathematical optimization.  
  - [`Gurobi.jl`](https://github.com/jump-dev/Gurobi.jl) — Julia interface to the Gurobi solver.  
  - [`CSV.jl`](https://csv.juliadata.org/stable/) — for reading and writing `.csv` files.  
  - [`DataFrames.jl`](https://dataframes.juliadata.org/stable/) — for handling tabular data.  
  - [`ArgParse.jl`](https://github.com/carlobaldassi/ArgParse.jl) — for parsing command-line arguments.  
  - [`Plots.jl`](https://docs.juliaplots.org/stable/) — for visualization.

⚠️ **Note:** You need a working installation of the [Gurobi Optimizer](https://www.gurobi.com/) with a valid license.
