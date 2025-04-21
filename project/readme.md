# Battery Market Simulation Tool 🔋

This tool provides a web-based interface for configuring battery parameters and running a Julia optimization model.

## Features

- Dynamic form input (HTML)
- Backend powered by Flask (Python)
- Optimization model in Julia using JuMP
- Auto-generated CSV + downloadable results

## Setup

```bash
git clone https://github.com/yourname/battery-simulator.git
cd battery-simulator

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

python server.py
