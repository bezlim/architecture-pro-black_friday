# MongoDB Sharding - Project

## Архитектура

Проект реализует шардирование MongoDB с:
- **configSrv1** — Config Server (порт 27019)
- **shard1-1** — Shard 1 (порт 27018)
- **shard2-1** — Shard 2 (порт 27020)
- **mongos1** — Router (порт 27017)
- **pymongo_api** — API приложение (порт 8081)

## Запуск проекта

```bash
docker compose up -d
```

## Настройка шардирования

Выполните скрипт инициализации:

```bash
chmod +x scripts/mongo-init.sh
./scripts/mongo-init.sh
```

Скрипт выполняет:
1. Инициализацию Replica Set для Config Server
2. Инициализацию Replica Set для Shard 1
3. Инициализацию Replica Set для Shard 2
4. Подключение шардов к кластеру
5. Включение шардирования для базы и коллекции
6. Заполнение данными (1000 документов)

## Проверка

После настройки доступен endpoint:

```
http://localhost:8081/
```

Ответ покажет:
- `mongo_topology_type`: "Sharded"
- `shards`: список шардов
- `collections`: количество документов в каждой коллекции

## Проверка количества документов в каждом шарде

```bash
# Shard 1
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# Shard 2
docker compose exec -T shard2-1 mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```
