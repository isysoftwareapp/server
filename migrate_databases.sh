# Database Migration Script
# This script migrates data from individual MongoDB instances to the centralized API MongoDB

## Step 1: Export Healthcare Data
echo "Exporting healthcare database..."
docker exec isy-healthcare-mongodb mongodump --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_clinic --out=/backup/healthcare

## Step 2: Export Retail Data
echo "Exporting retail database..."
docker exec retail-mongodb-dev mongodump --username=admin --password=admin123 --authenticationDatabase=admin --db=retail --out=/backup/retail

## Step 3: Import to Centralized MongoDB
echo "Importing healthcare data to centralized MongoDB..."
docker exec isy-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_api --nsFrom='isy_clinic.*' --nsTo='isy_api.*' /backup/healthcare/isy_clinic

echo "Importing retail data to centralized MongoDB..."
docker exec isy-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_api --nsFrom='retail.*' --nsTo='isy_api.*' /backup/retail/retail

## Alternative: Direct copy between containers
# If the old containers are still running, you can use mongodump/mongorestore with --archive flag

## For Windows PowerShell:
# Healthcare export and import
docker exec isy-healthcare-mongodb mongodump --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_clinic --archive | docker exec -i isy-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_api --archive

# Retail export and import  
docker exec retail-mongodb-dev mongodump --username=admin --password=admin123 --authenticationDatabase=admin --db=retail --archive | docker exec -i isy-mongodb mongorestore --username=admin --password=SecurePassword123! --authenticationDatabase=admin --db=isy_api --archive

## Verification
echo "Verifying data migration..."
docker exec isy-mongodb mongosh --username=admin --password=SecurePassword123! --authenticationDatabase=admin isy_api --eval "db.getCollectionNames()"
