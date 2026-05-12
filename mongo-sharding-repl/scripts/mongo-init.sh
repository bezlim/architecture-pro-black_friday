#!/bin/bash

echo "=== Ожидание запуска контейнеров MongoDB ==="
sleep 20

echo "=== Настройка Config Server Replica Set ==="
docker compose exec -T configSrv1 mongosh --port 27019 --quiet --eval "
rs.initiate({
  _id: \"cfgrs\",
  members: [{ _id: 0, host: \"configSrv1:27019\" }]
})
"
sleep 3
echo "Config Server Replica Set initialized"

echo "=== Настройка Shard 1 Replica Set ==="
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "
rs.initiate({
  _id: \"shard1\",
  members: [
    { _id: 0, host: \"shard1-1:27018\", priority: 2 },
    { _id: 1, host: \"shard1-2:27018\", priority: 1 },
    { _id: 2, host: \"shard1-3:27018\", priority: 1 }
  ]
})
"
sleep 3
echo "Shard 1 Replica Set initialized"

echo "=== Настройка Shard 2 Replica Set ==="
docker compose exec -T shard2-1 mongosh --port 27020 --quiet --eval "
rs.initiate({
  _id: \"shard2\",
  members: [
    { _id: 0, host: \"shard2-1:27020\", priority: 2 },
    { _id: 1, host: \"shard2-2:27020\", priority: 1 },
    { _id: 2, host: \"shard2-3:27020\", priority: 1 }
  ]
})
"
sleep 3
echo "Shard 2 Replica Set initialized"

echo "=== Подключение шардов к кластеру ==="
docker compose exec -T mongos1 mongosh --port 27017 --quiet --eval "
sh.addShard(\"shard1/shard1-1:27018\")
sh.addShard(\"shard2/shard2-1:27020\")
"
echo "Shards connected to cluster"

echo "=== Включение шардирования для базы и коллекции ==="
docker compose exec -T mongos1 mongosh --port 27017 --quiet --eval "
sh.enableSharding(\"somedb\")
sh.shardCollection(\"somedb.helloDoc\", { age: \"hashed\" })
"
echo "Sharding enabled"

echo "=== Заполнение данными ==="
docker compose exec -T mongos1 mongosh --port 27017 --quiet --eval "
db = db.getSiblingDB(\"somedb\")
for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: \"ly\" + i });
}
print(\"Inserted 1000 documents\");
"
echo "Data inserted"

echo "=== Проверка данных ==="
docker compose exec -T mongos1 mongosh --port 27017 --quiet --eval "
db = db.getSiblingDB(\"somedb\")
print(\"Общее количество документов: \" + db.helloDoc.countDocuments());

// Get shard distribution
let shards = db.adminCommand(\"listShards\").shards;
for (let shard of shards) {
  let shardHost = shard.host.split(\"/\")[1];
  let conn = new Mongo(\"mongodb://\" + shardHost + \"?directConnection=true\");
  let shardDb = conn.getDB(\"somedb\");
  let count = shardDb.helloDoc.countDocuments();
  print(\"\" + shard._id + \": \" + count + \" документов\");
}
"

echo "=== Готово! ==="
