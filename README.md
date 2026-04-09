# amneziawg-go-docker

# AmneziaWG VPN сервер в Docker — простой установщик

**Хотите свой VPN-сервер, но не хотите разбираться в сложных настройках?**

Этот скрипт сделает всё сам: установит Docker, настроит VPN, создаст ключи и запустит сервер. Вам нужно только выполнить несколько команд.

## 🎯 Что вы получите в итоге

- **Свой собственный VPN-сервер** на базе AmneziaWG (надёжный и быстрый протокол)
- **Защищённый доступ в интернет** с любого устройства (ноутбук, телефон, планшет)
- **Простое управление** — добавляйте и удаляйте пользователей одной командой

## 🧠 Что нужно знать перед началом

- **Сервер** — это компьютер в интернете, где будет стоять ваш VPN. Это может быть виртуальный сервер (VPS) от любого хостинг-провайдера (например, DigitalOcean, Hetzner, TimeWeb, RU-CENTER и др.)
- **Операционная система сервера** должна быть Linux. Скрипт поддерживает самые популярные версии: Ubuntu, Debian, Fedora, CentOS, Rocky Linux, AlmaLinux, openSUSE, Arch Linux.
- **Доступ к терминалу** — вы должны уметь подключаться к серверу по SSH (как правило, вам выдают логин, пароль и IP-адрес) или иметь доступ к терминалу иным способом (web-консоль, например). Покдлючение по SSH выглядит так:
   ```shell
   ssh username@host
   # Или
   ssh 1.2.3.4 -l username
   ```
- **права на sudo или доступ под пользователем root**

Если вы не уверены, подходит ли ваш сервер, — скорее всего, подходит. Просто попробуйте.

## 🚀 Быстрый старт — 3 команды

Скопируйте и выполните эти команды на сервере одну за другой:

```bash
# 1. Скачиваем скрипт установки
curl -O https://raw.githubusercontent.com/qreboot/amneziawg-go-docker/main/setup-amnezia.sh

# 2. Разрешаем его запуск
chmod +x setup-amnezia.sh

# 3. Запускаем установку (скрипт всё сделает сам)
sudo ./setup-amnezia.sh --install
```

Что произойдёт дальше?

   - Скрипт сам определит вашу операционную систему

   - Установит Docker (систему контейнеров)

   - Сгенерирует ключи шифрования

   - Настроит VPN-сервер

   - Запустит контейнер с VPN

   - Создаст готовый конфиг для первого пользователя — default_client

Вся установка занимает 2–5 минут. Вам не нужно ничего настраивать вручную.

## 📱 Как подключиться к вашему новому VPN
   1. Найдите файл с конфигурацией клиента:
      ```bash

      sudo cat /srv/containers/amnezia/conf/default_client.conf
      ```
      (Вы увидите текст, начинающийся с [Interface] — это и есть конфиг)

   2. Скачайте этот файл на свой компьютер / телефон (через SCP, SFTP или просто скопируйте текст)

   3. Установите приложение AmneziaWG на своё устройство:

      - Android: AmneziaWG на Google Play

      - Windows / macOS / Linux: скачайте с официального сайта Amnezia

      - iOS: в App Store ищите "AmneziaWG"

   4. Импортируйте конфиг в приложение:

      - На телефоне: отсканируйте QR-код (если сгенерировали) или выберите файл

      - На компьютере: откройте приложение → импорт конфига → выберите default_client.conf

   Включите VPN — нажмите "Подключиться".

Готово! Ваш интернет-трафик теперь защищён.

## 📋 Требования

- Linux сервер (см. список поддерживаемых ОС)
- Права root (sudo)
- Доступ в интернет


## ✨ Возможности

- 🚀 **Полная автоматизация** — установка Docker, генерация конфигов, запуск контейнера
- 🔑 **Генерация ключей**
- 🖥️ **Поддержка дистрибутивов** — Ubuntu, Debian, Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux, openSUSE, Arch Linux
- 👥 **Управление клиентами** — добавление, обновление, удаление через меню или CLI
- 📦 **Единый конфиг** — сервер и клиенты управляются через `awgcfg.py`


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
