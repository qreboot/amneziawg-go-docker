# amneziawg-go-docker

Интерактивный скрипт для автоматического развертывания **AmneziaWG** в Docker на популярных Linux дистрибутивах.

## ✨ Возможности

- 🚀 **Полная автоматизация** — установка Docker, генерация конфигов, запуск контейнера
- 🔑 **Генерация ключей**
- 🖥️ **Поддержка дистрибутивов** — Ubuntu, Debian, Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux, openSUSE, Arch Linux
- 👥 **Управление клиентами** — добавление, обновление, удаление через меню или CLI
- 📦 **Единый конфиг** — сервер и клиенты управляются через `awgcfg.py`

## 📋 Требования

- Linux сервер (см. список поддерживаемых ОС)
- Права root (sudo)
- Доступ в интернет

## 🚀 Быстрый старт

```bash
# Скачать скрипт
curl -O https://raw.githubusercontent.com/qreboot/amneziawg-go-docker/main/setup-amnezia.sh

# Сделать исполняемым
chmod +x setup-amnezia.sh

# Запустить полную установку
sudo ./setup-amnezia.sh --install
```
После установки вы получите:

   - ✅ Работающий VPN сервер в Docker

   - ✅ Клиент по умолчанию 

   - ✅ Конфиг клиента в /srv/containers/amnezia/conf/default_client.conf

## 📖 Использование

### Интерактивное меню

```bash
sudo ./setup-amnezia.sh
```

Меню позволяет:

   1. Полная установка

   2. Добавить клиента

   3. Список клиентов

   4. Обновить ключи клиента

   5. Удалить клиента

   6. Только установка Docker

   7. Только настройка sysctl

### Командная строка

```bash
# Полная установка
sudo ./setup-amnezia.sh --install

# Добавить клиента
sudo ./setup-amnezia.sh --add-client my_laptop 10.0.0.5

# Список клиентов
sudo ./setup-amnezia.sh --list-clients

# Обновить ключи клиента
sudo ./setup-amnezia.sh --update-client

# Удалить клиента
sudo ./setup-amnezia.sh --delete-client

# Помощь
sudo ./setup-amnezia.sh --help
```

### 🐳 Управление контейнером

```bash
# Просмотр логов
docker logs -f amnezia

# Остановка
docker stop amnezia

# Запуск
docker start amnezia

# Перезапуск
docker restart amnezia

# Статус
docker ps | grep amnezia
```

### 📁 Структура файлов

```text
/srv/containers/amnezia/conf/
├── awg0.conf                    # Конфиг сервера
├── client_template.conf         # Шаблон для клиентов
├── awgcfg.py                    # Утилита управления
├── default_client.conf          # Конфиг клиента по умолчанию
├── .main.config                 # Служебный файл awgcfg.py
└── *.conf                       # Конфиги добавленных клиентов
```

## 🔧 Конфигурация
### Параметры по умолчанию
| Параметр          | Значение                       |
|-------------------|--------------------------------|
|IP сервера	        | 10.0.0.1/24                    |
Порт                | 51820                          |
Интерфейс           | awg0                           |
Клиент по умолчанию | default_client (IP: 10.0.0.2)  |

### Изменение параметров
Отредактируйте переменные в начале скрипта:
```bash
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
```

## 👥 Управление клиентами
### Добавление клиента

```bash
sudo ./setup-amnezia.sh --add-client client_name 10.0.0.10
```
### Формат конфига клиента

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
#_PublicKey = <CLIENT_PUBLIC_KEY>
Address = <CLIENT_TUNNEL_IP>
DNS = <CLIENT_DNS>
Jc = <JC>
Jmin = <JMIN>
Jmax = <JMAX>
S1 = <S1>
S2 = <S2>
S3 = <S3>
S4 = <S4>
H1 = <H1>
H2 = <H2>
H3 = <H3>
H4 = <H4>
I1 = <I1>


[Peer]
AllowedIPs = <CLIENT_ALLOWED_IPs>
Endpoint = <SERVER_ADDR>:<SERVER_PORT>
PersistentKeepalive = 60
PublicKey = <SERVER_PUBLIC_KEY>
```

### Что нужно сделать клиенту
  1. Заменить YOUR_SERVER_IP на реальный IP сервера
  2. Импортировать конфиг в приложение AmneziaWG
  3. Подключиться

## 📄 Лицензия
MIT

# 🙏 Благодарности
[fviolence](https://hub.docker.com/r/fviolence/amneziawg-go)

[remittor](https://github.com/remittor)

[kyaru-b](https://github.com/kyaru-b)

[Amnezia](https://github.com/amnezia-vpn/amneziawg-go)
