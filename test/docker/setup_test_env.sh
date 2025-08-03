#!/bin/bash

# setup_test_env.sh - Redis Pool 测试环境配置脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 显示带颜色的消息
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理现有环境
cleanup() {
    log_info "清理测试环境..."
    docker-compose down -v
    log_info "清理完成！"
}

# 启动基本的 Redis 服务
start_basic_services() {
    log_info "启动基本 Redis 服务（Redis 6.2、Redis 7.0）..."
    docker-compose up -d redis6 redis7
    log_info "等待服务就绪..."
    sleep 5
    log_info "基本 Redis 服务启动完成！"
}




# 启动网络条件模拟服务
start_network_simulation() {
    log_info "启动网络条件模拟服务..."
    docker-compose up -d redis-delayed redis-unstable
    log_info "等待服务就绪..."
    sleep 5
    log_info "网络条件模拟服务启动完成！"
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    docker-compose ps
}

# 显示连接信息
show_connection_info() {
    log_info "Redis 连接信息:"
    echo -e "${GREEN}Redis 6.2:${NC} redis://:redis_password@localhost:6379"
    echo -e "${GREEN}Redis 7.0:${NC} redis://:redis_password@localhost:6380"
    echo -e "${GREEN}Redis Delayed:${NC} redis://:redis_password@localhost:6384"
    echo -e "${GREEN}Redis Unstable:${NC} redis://:redis_password@localhost:6385"
}

# 主函数
main() {
    case "$1" in
        start)
            start_basic_services
            start_network_simulation
            check_services
            show_connection_info
            ;;
        stop)
            log_info "停止所有服务..."
            docker-compose stop
            log_info "所有服务已停止！"
            ;;
        clean)
            cleanup
            ;;
        status)
            check_services
            show_connection_info
            ;;
        *)
            echo "用法: $0 {start|stop|clean|status}"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
