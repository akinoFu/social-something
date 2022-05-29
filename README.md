# Note for me
## After Creating the RDS Instance ...
### 1. Connect to MySQL with user "admin"
### 2. Create the DB and tables
```bash
wget https://raw.githubusercontent.com/sam-meech-ward-bcit/social_something_full/master/database.sql
```
### 3. Create a user for EC2 instances
```bash
CREATE USER 'web_app'@'172.31.%.%' IDENTIFIED WITH mysql_native_password BY 'MyNewPass1!';
GRANT ALL PRIVILEGES ON social_something.* TO 'web_app'@'172.31.%.%';
```