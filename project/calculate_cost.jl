function calculate_cost(data::Dict)


    function calculate_annuity(n::Int, r::Float64)
        """
        Calculate the annuity factor for an asset with lifetime n years and
        discount rate r, e.g. calculate_annuity(20, 0.05) * 20 = 1.6
        """
        if r > 0
            return r / (1.0 - 1.0 / (1.0 + r)^n)
        else
            return 1 / n
        end
    end

    # === Extract Common Parameters ===
    discount_rate = data["discount_rate"]
    max_hours = data["max_hours"]
    investment_store = data["investment_store"]
    investment_bicharger = data["investment_bicharger"]
    FOM_store = data["FOM_store"]
    FOM_bicharger = data["FOM_bicharger"]
    lifetime_store = data["lifetime_store"]
    lifetime_bicharger = data["lifetime_bicharger"]

    # === Calculate Number of Simulation Years ===
    start_date = Date(data["snapshots"]["start"], "yyyy-mm-dd")
    end_date = Date(data["snapshots"]["end"], "yyyy-mm-dd")
    days_diff = Dates.value(end_date - start_date) + 1
    Nyears = days_diff / 365.0 # divide 366 if it is a leap year, divide 365 otherwise (common year)


    # === Create a dictionary to store the cost of each energy storage system === 
    store_cost = Dict{String,Float64}()

    # === Calculate Cost for Each Storage Type ===
    for storage_name in keys(max_hours)
        # read the parameters of each storage
        hours = max_hours[storage_name]
        invest_store = investment_store[storage_name]
        invest_bicharger = investment_bicharger[storage_name]
        fom_store = FOM_store[storage_name]
        fom_bicharger = FOM_bicharger[storage_name]
        lt_store = lifetime_store[storage_name]
        lt_bicharger = lifetime_bicharger[storage_name]

        # caculate the power cost of battery and bicharger cost（€/kW）
        store_capital_cost = hours * ((calculate_annuity(lt_store, discount_rate) + fom_store / 100) * invest_store * Nyears)
        bicharger_capital_cost = (calculate_annuity(lt_bicharger, discount_rate) + fom_bicharger / 100) * invest_bicharger * Nyears

        # total_cost = capital cost + bicharger cost
        total_cost = store_capital_cost + bicharger_capital_cost

        # save the results in a dict
        store_cost[storage_name] = total_cost * 1000 # change to Euro/MW
    end

   
    return store_cost

end

