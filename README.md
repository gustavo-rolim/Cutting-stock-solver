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
