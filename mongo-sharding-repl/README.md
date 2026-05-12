# MongoDB Sharding with Replication

Этот проект демонстрирует MongoDB Sharding с репликацией на каждом шарде.

## Архитектура

- **Config Server**: 1 узел (configSrv1)
- **Shard 1**: 3 узла в Replica Set (shard1-1, shard1-2, shard1-3)
- **Shard 2**: 3 узла в Replica Set (shard2-1, shard2-2, shard2-3)
- **Mongos Router**: 1 узел (mongos1)
- **API**: 1 узел (pymongo_api)

## Запуск проекта

1. Запустите контейнеры:
   ```bash
   docker compose up -d
   ```

2. Дождитесь готовности контейнеров (примерно 20 секунд)

3. Инициализируйте Replica Set для Config Server:
   ```bash
   docker compose exec configSrv1 mongosh --port 27019 --eval "
   rs.initiate({
     _id: \"cfgrs\",
     members: [{ _id: 0, host: \"configSrv1:27019\" }]
   })
   "
   ```

4. Инициализируйте Replica Set для Shard 1:
   ```bash
   docker compose exec shard1-1 mongosh --port 27018 --eval "
   rs.initiate({
     _id: \"shard1\",
     members: [
       { _id: 0, host: \"shard1-1:27018\", priority: 2 },
       { _id: 1, host: \"shard1-2:27018\", priority: 1 },
       { _id: 2, host: \"shard1-3:27018\", priority: 1 }
     ]
   })
   "
   ```

5. Инициализируйте Replica Set для Shard 2:
   ```bash
   docker compose exec shard2-1 mongosh --port 27020 --eval "
   rs.initiate({
     _id: \"shard2\",
     members: [
       { _id: 0, host: \"shard2-1:27020\", priority: 2 },
       { _id: 1, host: \"shard2-2:27020\", priority: 1 },
       { _id: 2, host: \"shard2-3:27020\", priority: 1 }
     ]
   })
   "
   ```

6. Подключите шарды к кластеру:
   ```bash
   docker compose exec mongos1 mongosh --port 27017 --eval "
   sh.addShard(\"shard1/shard1-1:27018\")
   sh.addShard(\"shard2/shard2-1:27020\")
   "
   ```

7. Включите шардирование для базы и коллекции:
   ```bash
   docker compose exec mongos1 mongosh --port 27017 --eval "
   sh.enableSharding(\"somedb\")
   sh.shardCollection(\"somedb.helloDoc\", { age: \"hashed\" })
   "
   ```

8. Заполните данными:
   ```bash
   docker compose exec mongos1 mongosh --port 27017 --eval "
   db = db.getSiblingDB(\"somedb\")
   for (let i = 0; i < 1000; i++) {
     db.helloDoc.insertOne({ age: i, name: \"ly\" + i });
   }
   print(\"Inserted 1000 documents\");
   "
   ```

## Эндпоинты

- `GET /` - Информация о кластере
  - `mongo_topology_type`: "Sharded"
  - `shards`: список шардов с их hostами
  - `shard_docs`: распределение документов по шардам с количеством реплик
- `GET /{collection}/count` - Количество документов и распределение по шардам с репликами
- `GET /{collection}/users` - Список пользователей
- `POST /{collection}/users` - Создание нового пользователя

## Пример ответа

```json
{
  "mongo_topology_type": "Sharded",
  "shards": {
    "shard1": "shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018",
    "shard2": "shard2/shard2-1:27020,shard2-2:27020,shard2-3:27020"
  },
  "shard_docs": {
    "shard1": {"docs": 521, "replicas": 3},
    "shard2": {"docs": 479, "replicas": 3}
  }
}
```
