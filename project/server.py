from flask import Flask, request, jsonify, render_template, send_from_directory
import subprocess
import yaml
import os
# 自定义 float 显示为 0.0 而不是 0
def float_representer(dumper, value):
    return dumper.represent_scalar('tag:yaml.org,2002:float', f"{value:.1f}")

yaml.add_representer(float, float_representer)

app = Flask(__name__)

# 网页主入口
@app.route('/')
def index():
    return render_template("index.html")  # 自动从 templates/index.html 加载

# 接收表单 POST，生成 config.yaml，并运行 Julia 脚本
@app.route('/run', methods=['POST'])
def run():
    data = request.get_json()

    # 强制将 discount_rate 转为 float
    for key, val in data.items():
        if isinstance(val, int) and key == "discount_rate":
            data[key] = float(val)

    # 保存 config.yaml
    with open("project/config.yaml", "w") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, width=1000, sort_keys=False)

    print("📝 project/config.yaml 内容：")
    print(yaml.dump(data, default_flow_style=False, allow_unicode=True, width=1000, sort_keys=False))

    # 运行 Julia 脚本
    try:
        subprocess.check_output(["julia", "project/main_day_ahead.jl"], text=True)
    except subprocess.CalledProcessError as e:
        return jsonify({"output": f"Julia model error:\n{e.output}"}), 500
    except FileNotFoundError:
        return jsonify({"output": "project/main_day_ahead.jl, please make sure the file exists"}), 500

    # ✅ 读取并返回 results.txt 的内容
    result_text = ""
    results_txt_path = os.path.join("project", "Results", "results.txt")
    if os.path.exists(results_txt_path):
        with open(results_txt_path, "r") as f:
            result_text = f.read()
    else:
        result_text = "Did not find results.txt file"

    return jsonify({"output": result_text})




   
@app.route("/download")
def download_results():
    results_dir = os.path.join("project", "Results")
    abs_results_dir = os.path.abspath(results_dir)
    
    files = [f for f in os.listdir(abs_results_dir) if f.endswith(".csv")]
    if not files:
        return "Did not find the result file"
    
    latest_file = max(files)  # 或 files[-1] 取最新一个
    print("📎 Downloading:", latest_file, "from", abs_results_dir)
    
    return send_from_directory(directory=abs_results_dir, path=latest_file, as_attachment=True)


    

# 显示 config.yaml 文件内容（网页用）
@app.route('/view-config')
def view_config():
    if os.path.exists("project/config.yaml"):
        with open("project/config.yaml", "r") as f:
            content = f.read()
        return content
    else:
        return "project/config.yaml did not generate"

if __name__ == '__main__':
    app.run(debug=True)
