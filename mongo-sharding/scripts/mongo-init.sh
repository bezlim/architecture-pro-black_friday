#!/bin/bash

###
# Инициализация шардирования в MongoDB
###

echo "=== Настройка Config Server Replica Set ==="
docker compose exec -T configSrv1 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "cfgrs",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27019" }
  ]
})
EOF

echo "=== Настройка Shard 1 Replica Set ==="
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27018" }
  ]
})
EOF

echo "=== Настройка Shard 2 Replica Set ==="
docker compose exec -T shard2-1 mongosh --port 27020 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27020" }
  ]
})
EOF

echo "=== Подключение шардов к кластеру ==="
sleep 5
docker compose exec -T mongos1 mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018")
sh.addShard("shard2/shard2-1:27020")
EOF

echo "=== Включение шардирования для базы и коллекции ==="
docker compose exec -T mongos1 mongosh --port 27017 --quiet <<EOF
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { age: "hashed" })
EOF

echo "=== Заполнение данными ==="
docker compose exec -T mongos1 mongosh --port 27017 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

echo "=== Проверка данных ==="
docker compose exec -T mongos1 mongosh --port 27017 --quiet <<EOF
use somedb
print("Общее количество документов: " + db.helloDoc.countDocuments())

print("\\nШард 1:")
shard1_client = new Mongo("shard1-1:27018")
print("  Документов: " + shard1_client.getDB("somedb").helloDoc.countDocuments())

print("\\nШард 2:")
shard2_client = new Mongo("shard2-1:27020")
print("  Документов: " + shard2_client.getDB("somedb").helloDoc.countDocuments())
EOF
