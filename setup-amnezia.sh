#!/bin/bash

# =============================================================================
# AmneziaWG Docker Installer - Интерактивный режим
# =============================================================================
# Скрипт для автоматической установки, настройки и запуска AmneziaWG в Docker
# Поддерживает: Ubuntu, Debian, Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux,
#              openSUSE, Arch Linux
# =============================================================================

set -e  # Прерывать выполнение при ошибке

# -----------------------------------------------------------------------------
# Конфигурационные переменные
# -----------------------------------------------------------------------------
CONTAINER_NAME="amnezia"
HOST_CONF_DIR="/srv/containers/amnezia/conf"
CONTAINER_CONF_DIR="/etc/amnezia/amneziawg"
SERVER_CONF_FILE="awg0.conf"
SERVER_PORT="51820"
SERVER_INTERFACE="awg0"
SERVER_IP_NET="10.0.0.1/24"
DOCKER_IMAGE="ghcr.io/qreboot/amneziawg-go:v1.0.0"
DEFAULT_CLIENT_NAME="default_client"
DEFAULT_CLIENT_IP="10.0.0.2"

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
    echo "     AmneziaWG Docker Installer           "
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

install_python_and_deps() {
    log_step "Установка Python и необходимых зависимостей..."

    # Проверяем, установлен ли Python
    if ! command -v python3 &> /dev/null; then
        log_info "Установка Python3..."
        case $OS in
            ubuntu|debian|fedora|rocky|almalinux|rhel|centos|opensuse*)
                $INSTALL_CMD python3
                ;;
            arch)
                $INSTALL_CMD python
                ;;
        esac
    fi

    # Устанавливаем cryptography через пакетный менеджер
    log_info "Установка python3-cryptography..."
    case $OS in
        ubuntu|debian)
            $INSTALL_CMD python3-cryptography
            ;;
        fedora|rocky|almalinux)
            $INSTALL_CMD python3-cryptography
            ;;
        rhel|centos)
            if ! $INSTALL_CMD python3-cryptography 2>/dev/null; then
                $INSTALL_CMD epel-release 2>/dev/null || true
                $INSTALL_CMD python3-cryptography
            fi
            ;;
        opensuse-leap|opensuse-tumbleweed|sles)
            $INSTALL_CMD python3-cryptography
            ;;
        arch)
            $INSTALL_CMD python-cryptography
            ;;
    esac

    # Устанавливаем curl (если нет)
    if ! command -v curl &> /dev/null; then
        log_info "Установка curl..."
        $INSTALL_CMD curl
    fi

    # Финальная проверка
    log_step "Проверка работоспособности cryptography..."
    if ! python3 -c "from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey" 2>/dev/null; then
        log_error "cryptography не работает. Проверьте установку."
        exit 1
    fi

    log_info "Все зависимости установлены успешно."
}

configure_sysctl() {
    log_step "Настройка параметров sysctl..."

    # Временная настройка
    sysctl net.ipv4.conf.all.src_valid_mark=1 2>/dev/null || true
    sysctl net.ipv4.ip_forward=1 2>/dev/null || true

    # Постоянная настройка
    if ! grep -q "net.ipv4.conf.all.src_valid_mark" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.conf.all.src_valid_mark=1" >> /etc/sysctl.conf
    fi

    if ! grep -q "net.ipv4.ip_forward" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi

    log_info "Параметры sysctl настроены."
}

# -----------------------------------------------------------------------------
# Функции для работы с awgcfg.py
# -----------------------------------------------------------------------------
setup_directories() {
    log_step "Создание директории для конфигурации: $HOST_CONF_DIR"
    mkdir -p "$HOST_CONF_DIR"
    cd "$HOST_CONF_DIR"
    log_info "Директория создана."
}

download_awgcfg() {
    log_step "Скачивание утилиты awgcfg.py..."
    local awgcfg_url="https://raw.githubusercontent.com/qreboot/amneziawg-go-docker/refs/heads/main/awgcfg.py"
    curl -fsSL -o awgcfg.py "$awgcfg_url"
    chmod +x awgcfg.py
    log_info "awgcfg.py готов."
}

generate_server_config() {
    log_step "Генерация конфигурации сервера AmneziaWG..."
    cd "$HOST_CONF_DIR"

    if [[ -f "$SERVER_CONF_FILE" ]]; then
        log_warn "Файл $SERVER_CONF_FILE уже существует. Использую существующий."
        return 0
    fi

    python3 awgcfg.py --make "$SERVER_CONF_FILE" --ipaddr "$SERVER_IP_NET" --port "$SERVER_PORT" --tun "$SERVER_INTERFACE"
    log_info "Конфигурация сервера создана в файле $HOST_CONF_DIR/$SERVER_CONF_FILE"
}

create_client_template() {
    log_step "Создание шаблона для клиентских конфигов..."
    cd "$HOST_CONF_DIR"

    # Определяем внешний IP сервера
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP="YOUR_SERVER_IP"
        log_warn "Не удалось определить внешний IP. В шаблоне будет использован $SERVER_IP"
    else
        log_info "Внешний IP сервера: $SERVER_IP"
    fi

    local template_file="client_template.conf"
    if [[ -f "$template_file" ]]; then
        log_info "Шаблон уже существует: $template_file"
        return 0
    fi

    python3 awgcfg.py --create --ipaddr "$SERVER_IP" --tmpcfg "$template_file"
    log_info "Шаблон клиента создан: $HOST_CONF_DIR/$template_file"
}

add_default_client() {
    log_step "Добавление клиента по умолчанию: $DEFAULT_CLIENT_NAME"
    cd "$HOST_CONF_DIR"

    local template_file="client_template.conf"
    if [[ ! -f "$template_file" ]]; then
        template_file="_defclient.config"
    fi

    # Проверяем, существует ли уже клиент
    if grep -q "#_Name = $DEFAULT_CLIENT_NAME" "$SERVER_CONF_FILE" 2>/dev/null; then
        log_info "Клиент $DEFAULT_CLIENT_NAME уже существует."
        return 0
    fi

    # Добавляем клиента
    python3 awgcfg.py --addcl "$DEFAULT_CLIENT_NAME" --ipaddr "$DEFAULT_CLIENT_IP"

    # Генерируем конфиг
    python3 awgcfg.py --confgen "$DEFAULT_CLIENT_NAME" --tmpcfg "$template_file" --dns "8.8.8.8"

    if [[ -f "$HOST_CONF_DIR/$DEFAULT_CLIENT_NAME.conf" ]]; then
        log_info "✅ Клиент $DEFAULT_CLIENT_NAME добавлен. IP: $DEFAULT_CLIENT_IP"
    else
        log_error "Не удалось создать конфиг для клиента."
    fi
}

# -----------------------------------------------------------------------------
# Запуск контейнера
# -----------------------------------------------------------------------------
run_container() {
    log_step "Запуск Docker-контейнера AmneziaWG..."

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

    # Запуск контейнера
    docker run -d \
        -v "$HOST_CONF_DIR:$CONTAINER_CONF_DIR:ro" \
        -p "$SERVER_PORT:$SERVER_PORT/udp" \
        --name "$CONTAINER_NAME" \
        --cap-add=NET_ADMIN \
        --cap-add=SYS_MODULE \
        --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
        --sysctl="net.ipv4.ip_forward=1" \
        --device=/dev/net/tun:/dev/net/tun \
        -e "AMNEZIAWG_INTERFACE=$SERVER_INTERFACE" \
        --restart unless-stopped \
        --log-opt max-size=10m \
        --log-opt max-file=3 \
        "$DOCKER_IMAGE"

    if [[ $? -eq 0 ]]; then
        log_info "✅ Контейнер $CONTAINER_NAME успешно запущен."
    else
        log_error "Ошибка при запуске контейнера."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Отображение информации после установки
# -----------------------------------------------------------------------------
show_info() {
    # Получаем публичный ключ сервера
    local PUBLIC_KEY=""
    if [[ -f "$HOST_CONF_DIR/$SERVER_CONF_FILE" ]]; then
        PUBLIC_KEY=$(grep "^PublicKey" "$HOST_CONF_DIR/$SERVER_CONF_FILE" | awk '{print $3}')
    fi

    echo
    log_info "================== УСТАНОВКА ЗАВЕРШЕНА =================="
    echo "  Контейнер: $CONTAINER_NAME"
    echo "  Порт: $SERVER_PORT (UDP)"
    echo "  IP внутри VPN: $SERVER_IP_NET"
    echo "  Директория конфигов: $HOST_CONF_DIR"
    echo "  Публичный ключ сервера: ${PUBLIC_KEY:-Не найден}"
    echo
    log_info "Клиент по умолчанию:"
    echo "  Имя: $DEFAULT_CLIENT_NAME"
    echo "  IP: $DEFAULT_CLIENT_IP"
    echo "  Конфиг: $HOST_CONF_DIR/$DEFAULT_CLIENT_NAME.conf"
    echo
    log_info "Полезные команды:"
    echo "  Просмотр логов:    docker logs -f $CONTAINER_NAME"
    echo "  Остановка:         docker stop $CONTAINER_NAME"
    echo "  Запуск:            docker start $CONTAINER_NAME"
    echo "  Перезапуск:        docker restart $CONTAINER_NAME"
    echo "  Статус:            docker ps | grep $CONTAINER_NAME"
    echo "  Просмотр конфига:  cat $HOST_CONF_DIR/$SERVER_CONF_FILE"
    echo
    log_info "Управление клиентами:"
    echo "  Добавить клиента:   python3 $HOST_CONF_DIR/awgcfg.py --addcl <имя>"
    echo "  Сгенерировать конфиг: python3 $HOST_CONF_DIR/awgcfg.py --confgen <имя> --tmpcfg $HOST_CONF_DIR/client_template.conf"
    echo "  Удалить клиента:    python3 $HOST_CONF_DIR/awgcfg.py --delete <имя>"
    echo "============================================================="
}

# -----------------------------------------------------------------------------
# Полная установка
# -----------------------------------------------------------------------------
full_setup() {
    print_banner
    check_root
    detect_os
    configure_sysctl
    install_docker
    install_python_and_deps
    setup_directories
    download_awgcfg
    generate_server_config
    create_client_template
    add_default_client
    run_container
    show_info
}

# -----------------------------------------------------------------------------
# Интерактивное меню
# -----------------------------------------------------------------------------
show_menu() {
    print_banner
    echo "Выберите действие:"
    echo "=========================================="
    echo "1. Полная установка (Docker + настройка + контейнер + клиент)"
    echo "2. Добавить нового клиента"
    echo "3. Список клиентов"
    echo "4. Обновить ключи клиента"
    echo "5. Удалить клиента"
    echo "6. Только установка Docker"
    echo "7. Только настройка sysctl"
    echo "0. Выход"
    echo "=========================================="
}

add_client_interactive() {
    cd "$HOST_CONF_DIR"
    read -p "Введите имя клиента: " client_name

    if [[ -z "$client_name" ]]; then
        log_error "Имя клиента не может быть пустым."
        return 1
    fi

    read -p "Введите IP для клиента (например, 10.0.0.10): " client_ip

    if [[ -z "$client_ip" ]]; then
        log_error "IP клиента обязателен."
        return 1
    fi

    local template_file="client_template.conf"
    if [[ ! -f "$template_file" ]]; then
        template_file="_defclient.config"
    fi

    log_info "Добавление клиента: $client_name"
    python3 awgcfg.py --addcl "$client_name" --ipaddr "$client_ip"
    python3 awgcfg.py --confgen "$client_name" --tmpcfg "$template_file" --dns "8.8.8.8"

    if [[ -f "$HOST_CONF_DIR/$client_name.conf" ]]; then
        log_info "✅ Конфиг для клиента $client_name создан: $HOST_CONF_DIR/$client_name.conf"
        echo
        echo "----- НАСТРОЙКА КЛИЕНТА -----"
        echo "1. Отправьте файл $client_name.conf клиенту"
        echo "2. Клиент должен заменить в файле YOUR_SERVER_IP на реальный IP сервера"
        echo "3. Импортировать конфиг в приложение AmneziaWG"
        echo "----------------------------"
    else
        log_error "Не удалось создать конфиг для клиента."
        return 1
    fi
}

list_clients() {
    cd "$HOST_CONF_DIR"
    echo
    log_info "Список клиентов:"
    echo "----------------------------------------"
    if [[ -f "$SERVER_CONF_FILE" ]]; then
        grep -B 1 "AllowedIPs" "$SERVER_CONF_FILE" | grep -E "(#_Name|AllowedIPs)" | sed 's/#_Name = //; s/AllowedIPs = //' | paste -d " " - - | awk '{print "  Имя: " $1 " | IP: " $2}'
        echo "----------------------------------------"
    else
        log_warn "Файл конфигурации сервера $SERVER_CONF_FILE не найден."
    fi
}

update_client_interactive() {
    cd "$HOST_CONF_DIR"
    read -p "Введите имя клиента для обновления ключей: " client_name

    if [[ -z "$client_name" ]]; then
        log_error "Имя клиента не может быть пустым."
        return 1
    fi

    log_info "Обновление ключей для клиента $client_name..."
    python3 awgcfg.py --update "$client_name"

    local template_file="client_template.conf"
    if [[ ! -f "$template_file" ]]; then
        template_file="_defclient.config"
    fi
    python3 awgcfg.py --confgen "$client_name" --tmpcfg "$template_file" --dns "8.8.8.8"

    log_info "Ключи клиента $client_name обновлены. Конфиг перегенерирован."
}

delete_client_interactive() {
    cd "$HOST_CONF_DIR"
    read -p "Введите имя клиента для удаления: " client_name

    if [[ -z "$client_name" ]]; then
        log_error "Имя клиента не может быть пустым."
        return 1
    fi

    log_warn "Вы уверены, что хотите удалить клиента $client_name?"
    read -p "Это действие необратимо. Продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Удаление отменено."
        return 0
    fi

    python3 awgcfg.py --delete "$client_name"
    log_info "Клиент $client_name удален."
}

interactive_mode() {
    while true; do
        show_menu
        read -p "Ваш выбор [0-7]: " choice
        echo

        case $choice in
            1)
                full_setup
                break
                ;;
            2)
                check_root
                add_client_interactive
                ;;
            3)
                check_root
                list_clients
                ;;
            4)
                check_root
                update_client_interactive
                ;;
            5)
                check_root
                delete_client_interactive
                ;;
            6)
                check_root
                detect_os
                install_docker
                ;;
            7)
                check_root
                configure_sysctl
                ;;
            0)
                log_info "Выход."
                exit 0
                ;;
            *)
                log_error "Неверный выбор. Пожалуйста, выберите 0-7."
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
    --add-client)
        check_root
        shift
        if [[ -z "$1" ]]; then
            echo "Использование: $0 --add-client <имя> <IP>"
            exit 1
        fi
        cd "$HOST_CONF_DIR"
        local template_file="client_template.conf"
        if [[ ! -f "$template_file" ]]; then
            template_file="_defclient.config"
        fi
        python3 awgcfg.py --addcl "$1" --ipaddr "$2"
        python3 awgcfg.py --confgen "$1" --tmpcfg "$template_file" --dns "8.8.8.8"
        log_info "Клиент $1 добавлен. Конфиг: $HOST_CONF_DIR/$1.conf"
        ;;
    --list-clients)
        check_root
        list_clients
        ;;
    --update-client)
        check_root
        update_client_interactive
        ;;
    --delete-client)
        check_root
        delete_client_interactive
        ;;
    --help)
        echo "Использование: $0 [КОМАНДА]"
        echo ""
        echo "  --install                - Полная установка"
        echo "  --add-client <имя> <IP>  - Добавить клиента"
        echo "  --list-clients           - Список клиентов"
        echo "  --update-client          - Обновить ключи клиента"
        echo "  --delete-client          - Удалить клиента"
        echo "  --help                   - Показать справку"
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