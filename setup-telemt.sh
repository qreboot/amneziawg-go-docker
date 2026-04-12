#!/bin/bash

# =============================================================================
# Telemt Docker Installer - Интерактивный режим
# =============================================================================
# Скрипт для автоматической установки, настройки и запуска Telemt в Docker
# Поддерживает: Ubuntu, Debian, Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux,
#              openSUSE, Arch Linux
# =============================================================================

set -e  # Прерывать выполнение при ошибке

# -----------------------------------------------------------------------------
# Конфигурационные переменные
# -----------------------------------------------------------------------------
CONTAINER_NAME="telemt"
HOST_CONF_DIR="/srv/containers/telemt"
CONTAINER_CONF_DIR="/app"
CONFIG_FILE="config.toml"

TELEMT_PORT="443"
API_PORT="9091"
DOCKER_IMAGE="ghcr.io/telemt/telemt:latest"
DEFAULT_SECRET=""
DEFAULT_TAG=""
TLS_DOMAIN=""
PUBLIC_HOST=""
SERVER_PORT="443"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Вспомогательные функции
# -----------------------------------------------------------------------------
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

print_banner() {
    echo -e "${CYAN}"
    echo "=========================================="
    echo "        Telemt Docker Installer           "
    echo "=========================================="
    echo -e "${NC}"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен выполняться с правами root (sudo)."
        exit 1
    fi
}

# Определение типа ОС и пакетного менеджера
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "Не удалось определить операционную систему."
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt-get"
            INSTALL_CMD="apt-get install -y"
            UPDATE_CMD="apt-get update"
            ;;
        fedora|rocky|almalinux)
            PKG_MANAGER="dnf"
            INSTALL_CMD="dnf install -y"
            UPDATE_CMD="dnf check-update"
            ;;
        rhel|centos)
            PKG_MANAGER="yum"
            INSTALL_CMD="yum install -y"
            UPDATE_CMD="yum check-update"
            ;;
        opensuse-leap|opensuse-tumbleweed|sles)
            PKG_MANAGER="zypper"
            INSTALL_CMD="zypper --non-interactive install"
            UPDATE_CMD="zypper --non-interactive refresh"
            ;;
        arch)
            PKG_MANAGER="pacman"
            INSTALL_CMD="pacman -S --noconfirm"
            UPDATE_CMD="pacman -Syu --noconfirm"
            ;;
        *)
            log_error "Неподдерживаемая операционная система: $OS"
            exit 1
            ;;
    esac
    log_info "Обнаружена ОС: $OS ($VER)"
}

# -----------------------------------------------------------------------------
# Функции установки зависимостей
# -----------------------------------------------------------------------------
install_docker() {
    log_step "Проверка/Установка Docker..."

    if command -v docker &> /dev/null; then
        log_info "Docker уже установлен. Версия: $(docker --version)"
        return 0
    fi

    log_info "Установка Docker..."

    case $OS in
        ubuntu|debian)
            $UPDATE_CMD
            $INSTALL_CMD ca-certificates curl gnupg lsb-release
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            $UPDATE_CMD
            $INSTALL_CMD docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        fedora|rocky|almalinux|rhel|centos)
            $INSTALL_CMD yum-utils 2>/dev/null || $INSTALL_CMD dnf-plugins-core
            yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo 2>/dev/null || dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
            $INSTALL_CMD docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        opensuse-leap|opensuse-tumbleweed|sles)
            $INSTALL_CMD docker docker-compose-plugin
            ;;
        arch)
            $INSTALL_CMD docker docker-compose
            ;;
    esac

    systemctl enable docker
    systemctl start docker

    if command -v docker &> /dev/null; then
        log_info "Docker успешно установлен."
    else
        log_error "Не удалось установить Docker."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Функции генерации конфигурации
# -----------------------------------------------------------------------------
generate_secret() {
    # Генерируем случайный секрет (32 символа)
    openssl rand -hex 16 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}

get_docker_bridge_ip() {
    ip addr show docker0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "172.17.0.1"
}

generate_config_content() {
    local conf_secret="$1"
    local conf_tag="$2"
    local escaped_tls_domain="$(printf '%s\n' "$TLS_DOMAIN" | tr -d '[:cntrl:]' | sed 's/\\/\\\\/g; s/"/\\"/g')"

    cat <<EOF
[general]
use_middle_proxy = true
EOF

    if [ -n "$conf_tag" ]; then
        echo "ad_tag = \"${conf_tag}\""
    fi

    cat <<EOF

[general.modes]
classic = false
secure = false
tls = true

[general.links]
show = "*"
public_host = "$PUBLIC_HOST"
public_port = $SERVER_PORT

[server]
port = ${SERVER_PORT}

[server.api]
enabled = true
listen = "0.0.0.0:9091"
whitelist = ["0.0.0.0/0"]
minimal_runtime_enabled = false
minimal_runtime_cache_ttl_ms = 1000

[[server.listeners]]
ip = "0.0.0.0"

[censorship]
tls_domain = "${escaped_tls_domain}"
mask = true
tls_emulation = true
tls_front_dir = "tlsfront"

[access.users]
hello = "${conf_secret}"
EOF
}

setup_directories() {
    log_step "Создание директорий для Telemt..."
    mkdir -p "$HOST_CONF_DIR/config"
    log_info "Директории созданы: $HOST_CONF_DIR"
}

generate_config() {
    log_step "Генерация конфигурационного файла Telemt..."

    cd "$HOST_CONF_DIR/config"

    # Запрос параметров у пользователя
    echo
    read -p "Введите домен для TLS (например, example.com): " TLS_DOMAIN
    if [[ -z "$TLS_DOMAIN" ]]; then
        log_error "Домен обязателен для TLS."
        exit 1
    fi

    read -p "Введите секрет доступа (оставьте пустым для автоматической генерации): " input_secret
    if [[ -z "$input_secret" ]]; then
        DEFAULT_SECRET=$(generate_secret)
        log_info "Сгенерирован случайный секрет: $DEFAULT_SECRET"
    else
        DEFAULT_SECRET="$input_secret"
    fi

    read -p "Введите ad_tag (метка для рекламы, опционально): " DEFAULT_TAG

    read -p "Введите порт сервера [$TELEMT_PORT]: " input_port
    SERVER_PORT=${input_port:-$TELEMT_PORT}

    read -p "Введите публичный адрес сервера (например, $TLS_DOMAIN или 176.74.20.150): " PUBLIC_HOST
    if [[ -z "$PUBLIC_HOST" ]]; then
        PUBLIC_HOST="$TLS_DOMAIN"
    fi

    # Генерируем конфиг
    generate_config_content "$DEFAULT_SECRET" "$DEFAULT_TAG" > "$CONFIG_FILE"
    chown -R 65532:65532 "$HOST_CONF_DIR/config"
    log_info "Конфигурационный файл создан: $HOST_CONF_DIR/config/$CONFIG_FILE"
}

# -----------------------------------------------------------------------------
# Запуск контейнера
# -----------------------------------------------------------------------------
run_container() {
    log_step "Запуск Docker-контейнера Telemt..."

    # Остановить и удалить старый контейнер, если есть
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_warn "Контейнер $CONTAINER_NAME уже существует."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        log_info "Старый контейнер удален."
    fi

    # Проверка наличия образа
    if ! docker image inspect "$DOCKER_IMAGE" &> /dev/null; then
        log_warn "Образ $DOCKER_IMAGE не найден локально. Пробуем скачать..."
        docker pull "$DOCKER_IMAGE"
    fi

    # Получаем IP Docker-моста для привязки API
    DOCKER_BRIDGE_IP=$(get_docker_bridge_ip)

    # Запуск контейнера
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "$SERVER_PORT:$SERVER_PORT" \
        -p "$DOCKER_BRIDGE_IP:9091:9091" \
        -e "RUST_LOG=silent" \
        -v "$HOST_CONF_DIR/config/config.toml:/app/config.toml:rw" \
        --cap-drop ALL \
        --cap-add NET_BIND_SERVICE \
        --ulimit nofile=65536:65536 \
        --log-opt max-size=10m \
        --log-opt max-file=3 \
        "$DOCKER_IMAGE"

    if [[ $? -eq 0 ]]; then
        log_info "Контейнер $CONTAINER_NAME успешно запущен."
    else
        log_error "Ошибка при запуске контейнера."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Функции получения информации
# -----------------------------------------------------------------------------
get_telemt_url() {
    local bridge_ip="$1"
    local api_url="http://${bridge_ip}:9091/v1/users"
    local tls_link=""

    # Проверяем, что контейнер запущен и API отвечает
    if curl -s --max-time 5 "$api_url" > /dev/null 2>&1; then
        local response
        response=$(curl -s "$api_url")

        # Безопасное извлечение TLS ссылки с помощью jq
        if command -v jq &> /dev/null; then
            tls_link=$(echo "$response" | jq -r 'try .data[0].links.tls[0] catch ""' 2>/dev/null)
        else
            # Fallback без jq
            tls_link=$(echo "$response" | grep -oP '"tls":\[\K"[^"]+"' | tr -d '"' | head -1)
        fi
    fi

    echo "$tls_link"
}

# -----------------------------------------------------------------------------
# Отображение информации после установки
# -----------------------------------------------------------------------------
show_info() {
    local bridge_ip=$(get_docker_bridge_ip)

    # Пытаемся получить URL от API
    local telemt_url=$(get_telemt_url "$bridge_ip")

    echo
    log_info "================== УСТАНОВКА ЗАВЕРШЕНА =================="
    echo "  Контейнер: $CONTAINER_NAME"
    echo "  Директория конфигов: $HOST_CONF_DIR/config"
    echo
    log_info "API (доступно только с хоста):"
    echo "  API: http://$bridge_ip:9091"
    echo
    log_info "Полезные команды:"
    echo "  Просмотр логов:    docker logs -f $CONTAINER_NAME"
    echo "  Остановка:         docker stop $CONTAINER_NAME"
    echo "  Запуск:            docker start $CONTAINER_NAME"
    echo "  Перезапуск:        docker restart $CONTAINER_NAME"
    echo "  Статус:            docker ps | grep $CONTAINER_NAME"
    echo "  Просмотр конфига:  cat $HOST_CONF_DIR/config/$CONFIG_FILE"
    echo
    log_info "Для подключения к Telemt используйте:"
    echo "   URL: $telemt_url"
    echo "============================================================="
}

# -----------------------------------------------------------------------------
# Полная установка
# -----------------------------------------------------------------------------
full_setup() {
    print_banner
    check_root
    detect_os
    install_docker
    setup_directories
    generate_config
    run_container

    # Небольшая задержка перед показом информации (чтобы API успело запуститься)
    sleep 3
    show_info
}

# -----------------------------------------------------------------------------
# Интерактивное меню
# -----------------------------------------------------------------------------
show_menu() {
    print_banner
    echo "Выберите действие:"
    echo "=========================================="
    echo "1. Полная установка (Docker + настройка + контейнер)"
    echo "2. Только установка Docker"
    echo "3. Только генерация конфигурации"
    echo "4. Запустить контейнер"
    echo "5. Остановить контейнер"
    echo "6. Перезапустить контейнер"
    echo "7. Показать информацию о подключении"
    echo "8. Обновить секрет доступа"
    echo "0. Выход"
    echo "=========================================="
}

regenerate_secret() {
    log_step "Обновление секрета доступа..."

    NEW_SECRET=$(generate_secret)
    log_info "Новый секрет: $NEW_SECRET"

    # Обновляем конфиг
    cd "$HOST_CONF_DIR/config"
    generate_config_content "$NEW_SECRET" "$DEFAULT_TAG" > "$CONFIG_FILE"

    # Перезапускаем контейнер
    docker restart "$CONTAINER_NAME"

    log_info "Секрет обновлен. Контейнер перезапущен."
    echo "Новый секрет: $NEW_SECRET"
}

show_connection_info() {
    local bridge_ip=$(get_docker_bridge_ip)
    local telemt_url=$(get_telemt_url "$bridge_ip")
    echo "   URL: $telemt_url"

}

interactive_mode() {
    while true; do
        show_menu
        read -p "Ваш выбор [0-8]: " choice
        echo

        case $choice in
            1)
                full_setup
                break
                ;;
            2)
                check_root
                detect_os
                install_docker
                ;;
            3)
                check_root
                setup_directories
                generate_config
                ;;
            4)
                check_root
                run_container
                ;;
            5)
                check_root
                docker stop "$CONTAINER_NAME" 2>/dev/null && log_info "Контейнер остановлен" || log_warn "Контейнер не запущен"
                ;;
            6)
                check_root
                docker restart "$CONTAINER_NAME" 2>/dev/null && log_info "Контейнер перезапущен" || log_warn "Контейнер не запущен"
                ;;
            7)
                show_connection_info
                ;;
            8)
                check_root
                regenerate_secret
                ;;
            0)
                log_info "Выход."
                exit 0
                ;;
            *)
                log_error "Неверный выбор. Пожалуйста, выберите 0-8."
                ;;
        esac
        echo
        read -p "Нажмите Enter для продолжения..."
    done
}

# -----------------------------------------------------------------------------
# Обработка аргументов командной строки
# -----------------------------------------------------------------------------
case "$1" in
    --install)
        full_setup
        ;;
    --show-info)
        show_connection_info
        ;;
    --regenerate-secret)
        check_root
        regenerate_secret
        ;;
    --help)
        echo "Использование: $0 [КОМАНДА]"
        echo ""
        echo "  --install            - Полная установка"
        echo "  --show-info          - Показать информацию для подключения"
        echo "  --regenerate-secret  - Сгенерировать новый секрет доступа"
        echo "  --help               - Показать справку"
        echo ""
        echo "Запуск без параметров открывает интерактивное меню."
        ;;
    "")
        interactive_mode
        ;;
    *)
        echo "Неизвестная команда: $1"
        echo "Используйте $0 --help для получения справки."
        exit 1
        ;;
esac

exit 0