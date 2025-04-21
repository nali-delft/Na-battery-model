function opt_day_ahead(
    ts::DataFrame,
    data::Dict,
    battery_cost::Dict,
    price_df::DataFrame,
    selected_batteries::Vector{String}  # selected battery technologies
)
    

    # === Preparation ===
    tt = data["general"]["nTimesteps"]
    JH = ts[!, :step][1:tt]

    # extract hourly day-ahead prices
    price = price_df.price[1:tt]
    max_ex = maximum([data["battery_size"][b] for b in selected_batteries])
    # create an optimization model
    model = Model(HiGHS.Optimizer)
    


    # Define variables
    buy = @variable(model, buy[JH], lower_bound = 0, upper_bound = max_ex)
    sell = @variable(model, sell[JH], lower_bound = 0, upper_bound = max_ex)


    # === Battery Structures ===
    bat_power = Dict{String,Any}()
    bat_cap = Dict{String,Any}()
    bat_eff = Dict{String,Any}()
    RTE = Dict{String,Any}()
    cha = Dict{String,Vector{VariableRef}}()
    dis = Dict{String,Vector{VariableRef}}()
    bat_soc = Dict{String,Vector{VariableRef}}()
    # cha = Dict{String,Any}()
    # dis_sell = Dict{String,Any}()
    # bat_soc = Dict{String,Any}()
    u = Dict{String,Any}()



    for battery_name in selected_batteries
        # charge and discharge efficiency
        RTE[battery_name] = data["RTE_efficiency"][battery_name]
        bat_eff[battery_name] = sqrt(RTE[battery_name])
        # read power and energy capacity of each battery
        bat_power[battery_name] = data["battery_size"][battery_name]
        bat_cap[battery_name] = data["battery_size"][battery_name] * data["max_hours"][battery_name] * bat_eff[battery_name]
    
        # define charge, discharge, and soc of each battery
        cha[battery_name] = @variable(model, [h in JH], base_name = "cha_$battery_name", lower_bound = 0, upper_bound = bat_power[battery_name])
        dis[battery_name] = @variable(model, [h in JH], base_name = "dis_$battery_name", lower_bound = 0, upper_bound = bat_power[battery_name])
        bat_soc[battery_name] = @variable(model, [h in JH], base_name = "bat_soc_$battery_name", lower_bound = 0, upper_bound = bat_cap[battery_name])
        u[battery_name] = @variable(model, [h in JH], base_name = "binary_$battery_name", Bin)
        # define constraints of each battery
        # @constraint(model, bat_cap[battery_name] == data["max_hours"][battery_name] * bat_power[battery_name]*bat_eff)

        # === Energy Balance Constraints ===
        # initial SOC
        @constraint(model, bat_soc[battery_name][1] == 0.5* bat_cap[battery_name])
        @constraint(model, [h = 2:JH[end]],
            bat_soc[battery_name][h] == bat_soc[battery_name][h-1] + bat_eff[battery_name] * cha[battery_name][h] - dis[battery_name][h] * (1 / bat_eff[battery_name])
        )
        # initial SOC = end SOC
        @constraint(model, bat_soc[battery_name][end] == bat_soc[battery_name][1])

        
        # make sure charge and discharge do not happen at the same time 

        # @constraint(model, [h in JH], cha[battery_name][h] * dis[battery_name][h] == 0)
    


        # charge and discharge power constraints
        @constraint(model, [h in JH], cha[battery_name][h] <= u[battery_name][h] * bat_power[battery_name])
        @constraint(model, [h in JH], dis[battery_name][h] <= (1 - u[battery_name][h]) * bat_power[battery_name])
    end

    # === Market Flow Constraints (shared grid connection) ===
    @constraint(model, [h in JH], sum(cha[battery_name][h] for battery_name in selected_batteries) == buy[h])
    @constraint(model, [h in JH], sum(dis[battery_name][h] for battery_name in selected_batteries) == sell[h])

    # === Objective Function === 
    # minimize total cost =  investment cost -  profits

    @objective(
        model,
        Min,
        sum(battery_cost[battery_name] * bat_power[battery_name] for battery_name in selected_batteries) +
        sum(price[h] * buy[h] for h in JH) - sum(price[h] * sell[h] for h in JH)
    )

    # === Solve Optimization ===
    optimize!(model)
    if termination_status(model)!= MOI.OPTIMAL
        println("Optimization did not find an optimal solution")
        return nothing
    end

    # === Extract Results ===
    r_cost = objective_value(model)
    r_buy = value.(buy)
    r_sell = value.(sell)
    r_cha = Dict(battery_name => value.(cha[battery_name]) for battery_name in selected_batteries)
    r_dis = Dict(battery_name => value.(dis[battery_name]) for battery_name in selected_batteries)
    r_bat_soc = Dict(battery_name => value.(bat_soc[battery_name]) for battery_name in selected_batteries)

    return r_cost, r_buy, r_sell, r_cha, r_dis, r_bat_soc, model
end


