# syntax=docker/dockerfile:1
# ============================================================================
# LifeScale 后端镜像（多阶段构建）
# ----------------------------------------------------------------------------
# 设计要点：
# - 多阶段：构建阶段用 maven:3.9-eclipse-temurin-21（含 Maven + JDK 21），运行阶段
#   仅含 eclipse-temurin:21-jre-jammy（JRE），最终镜像小、攻击面小。
# - 服务器无需预装 Maven / JDK，只需 git pull + docker compose build。
# - 依赖层缓存：先 COPY pom.xml 单独跑 dependency:go-offline，源码改动不触发
#   依赖重下载（仅 pom 变化才重下），大幅加速日常构建。
# - jar 名通配：Maven 实际产物为 lifescale-backend-0.1.0.jar，用通配匹配避免硬编码。
# - 健康检查：打 /api/health（项目已实现，无需额外 actuator 端点）。
# ============================================================================

# ---------- 阶段 1：构建 ----------
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build

# 注入阿里云 Maven 镜像（国内服务器/CI 加速，依赖下载从 9 分钟 → 2-3 分钟）
# 与 pom.xml 的 repositories 形成双重保险（pom.xml 是仓库声明，settings.xml 是镜像拦截）
RUN mkdir -p /root/.m2 && cat > /root/.m2/settings.xml << 'EOF'
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <mirrors>
    <mirror>
      <id>aliyun-central</id>
      <name>Aliyun Central Mirror</name>
      <url>https://maven.aliyun.com/repository/central</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
    <mirror>
      <id>aliyun-public</id>
      <name>Aliyun Public Mirror</name>
      <url>https://maven.aliyun.com/repository/public</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>
</settings>
EOF

# 先复制 pom，单独缓存依赖层（源码变更不重下依赖）
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

# 复制源码并打包（跳过测试：镜像构建只做产物，测试在 CI/本地单独跑）
COPY src ./src
RUN mvn -B -q clean package -DskipTests

# ---------- 阶段 2：运行 ----------
FROM eclipse-temurin:21-jre-jammy AS runtime

LABEL maintainer="lifescale"

# 时区（COS 上传时间戳、日志时间统一东八区）
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 健康检查需要 curl（基础 JRE 镜像不带）
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制构建产物（通配匹配 lifescale-backend-<version>.jar，避免硬编码版本号）
COPY --from=builder /build/target/lifescale-backend-*.jar /app/app.jar

# JVM 参数（容器感知：堆占比按容器内存 65%、G1GC、OOM 自动 dump、UTF-8）
ENV JAVA_OPTS="-XX:MaxRAMPercentage=65 -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8"

EXPOSE 8080

# 健康检查：打 /api/health，期望返回 status=UP
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS http://localhost:8080/api/health | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
