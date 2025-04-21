# 基础镜像：Python + Julia
FROM python:3.11-slim

# 安装 Julia
RUN apt-get update && apt-get install -y wget gcc g++ git curl \
 && curl -fsSL https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.2-linux-x86_64.tar.gz | tar -xz -C /opt \
 && ln -s /opt/julia-1.10.2/bin/julia /usr/local/bin/julia

# 设置工作目录
WORKDIR /app

# 拷贝项目文件
COPY . .

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 设置 Flask 环境变量
ENV FLASK_APP=project/server.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_RUN_PORT=8080

# 启动 Flask 应用
CMD ["flask", "run"]
