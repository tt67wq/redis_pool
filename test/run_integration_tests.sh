#!/bin/bash

# run_integration_tests.sh - Redis Pool 集成测试运行脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR/..

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 启动 Docker 测试环境
start_test_environment() {
    log_step "启动 Redis 测试环境..."
    cd $SCRIPT_DIR/docker && ./setup_test_env.sh start
    if [ $? -ne 0 ]; then
        log_error "启动测试环境失败"
        exit 1
    fi
    log_info "测试环境已启动"
    sleep 5 # 等待服务完全启动
}

# 停止 Docker 测试环境
stop_test_environment() {
    log_step "停止 Redis 测试环境..."
    cd $SCRIPT_DIR/docker && ./setup_test_env.sh stop
    log_info "测试环境已停止"
}

# 清理 Docker 测试环境
clean_test_environment() {
    log_step "清理 Redis 测试环境..."
    cd $SCRIPT_DIR/docker && ./setup_test_env.sh clean
    log_info "测试环境已清理"
}

# 运行单实例测试
run_standalone_tests() {
    log_step "运行 Redis 单实例测试..."
    CHECK_REDIS_ENV=true mix test test/integration/standalone_test.exs
}

# Sentinel 测试已移除 - 此客户端不支持 Sentinel 模式

# 运行网络条件测试
run_network_tests() {
    log_step "运行 Redis 网络条件测试..."
    CHECK_REDIS_ENV=true mix test test/integration/network_test.exs
}

# 运行所有集成测试
run_all_tests() {
    log_step "运行所有集成测试..."
    CHECK_REDIS_ENV=true mix test test/integration/
}

# 显示帮助信息
show_help() {
    echo "Redis Pool 集成测试运行脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  start          启动测试环境"
    echo "  stop           停止测试环境"
    echo "  clean          清理测试环境"
    echo "  standalone     运行 Redis 单实例测试"
    echo "  network        运行 Redis 网络条件测试"
    echo "  all            运行所有集成测试"
    echo "  full           启动环境，运行所有测试，然后清理环境"
    echo "  help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start       # 启动测试环境"
    echo "  $0 standalone  # 运行 Redis 单实例测试"
    echo "  $0 full        # 完整的测试周期"
}

# 主函数
main() {
    case "$1" in
        start)
            start_test_environment
            ;;
        stop)
            stop_test_environment
            ;;
        clean)
            clean_test_environment
            ;;
        standalone)
            run_standalone_tests
            ;;
        sentinel)
            log_error "Sentinel 测试已移除 - 此客户端不支持 Sentinel 模式"
            exit 1
            ;;
        network)
            run_network_tests
            ;;
        all)
            run_all_tests
            ;;
        full)
            log_step "执行完整测试周期..."
            start_test_environment
            run_all_tests
            stop_test_environment
            log_info "完整测试周期已完成"
            ;;
        help|*)
            show_help
            ;;
    esac
}

# 执行主函数
main "$@"
