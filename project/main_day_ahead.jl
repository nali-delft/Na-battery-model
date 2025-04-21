# ===============================
# File: simulate_day_ahead.jl
# Author: Na Li
# Date: 8 April, 2025
# Description:
# Simulates IronAir and other batteries participating in the day-ahead market using JuMP optimization.
# The goal is to calculate the annual optimal profit: (annual revenue - annualized battery investment cost).
# Assumptions:
# - Grid connection capacity equals battery power
# - Grid connection fees and country-specific policy support are excluded
# ===============================


# === Load Libraries ===
using JuMP, YAML, CSV, DataFrames, Plots, Statistics, HiGHS, LaTeXStrings, Dates

# === Load Internal Modules ===
home_dir = @__DIR__
include(joinpath(home_dir, "calculate_cost.jl"))
include(joinpath(home_dir, "opt_day_ahead.jl"))

# === Step 1: Load Config Data ===
config_path = joinpath(home_dir, "config.yaml")
data = YAML.load_file(config_path)

# === Step 2: Calculate Battery Costs ===
battery_cost = calculate_cost(data)

# === Step 3: Load Market Price Data ===
price_path = joinpath(home_dir, "Inputs", "Day-ahead-prices-2023.csv")
price_df = CSV.read(price_path, DataFrame)

# === Step 4: Define Time Series ===
nTimesteps = data["general"]["nTimesteps"]
ts = DataFrame(step=1:nTimesteps)

# === Step 5: Define Battery Portfolio ===
selected_batteries = ["IronAir"]

# === Step 6: Run Optimization Model ===
opt_cost = zeros()
buy = zeros()
sell = zeros()
cha = Dict{String,Any}()
dis = Dict{String,Any}()
bat_soc = Dict{String,Any}()

opt_cost, buy, sell, cha, dis, bat_soc = opt_day_ahead(ts, data, battery_cost, price_df, selected_batteries)


# === Step 7: Display Results ===
println("Optimal cost is: $opt_cost")


# === Step 7: Generate time column ===
start_time = DateTime(data["snapshots"]["start"])
end_time = DateTime(data["snapshots"]["end"]) + Day(1)
datetime_index = collect(start_time:Hour(1):end_time-Hour(1))  # ✅ 包含到 12/31 23:00
ts = DataFrame(time=datetime_index[1:nTimesteps])
# === Step 8: Build result dataframe ===
result_df = DataFrame()
result_df = DataFrame(
    time=ts.time,
    price=price_df.price,
    buy=Vector(buy),
    sell=Vector(sell),
)


# result_df = DataFrame(
#     price=price_df.price,
#     buy=Vector(buy),
#     sell=Vector(sell),
# )

# === Step 8: Store Simulation Results ===
columns = ["cha", "dis", "bat_soc"]


for battery_name in selected_batteries
    for col in columns
        var_data = eval(Symbol(col))[battery_name]
        result_df[!, "$(col)_$(battery_name)"] = round.(var_data, digits=2)
    end
end

# Create results folder if not exists
results_folder = joinpath(home_dir, "Results")
if !isdir(results_folder)
    mkdir(results_folder)
end

# Build filename from selected batteries and hours
hours = join([data["max_hours"][b] for b in selected_batteries], "_")
battery_names = join(selected_batteries, "_")
file_name = "$(battery_names)_hour_$(hours)_day_ahead.csv"
file_path = joinpath(results_folder, file_name)
CSV.write(file_path, result_df)

# === Step 9: Report Battery Costs ===
for battery_name in selected_batteries
    println("Battery cost of $battery_name: ", battery_cost[battery_name])
end


open(joinpath(home_dir, "Results", "results.txt"), "w") do f
    println(f, "Optimal cost: $opt_cost")
    for battery_name in selected_batteries
        println(f, "Battery cost of $battery_name: $(battery_cost[battery_name])")
    end
    println(f, "Results CSV file: $file_name")
end
