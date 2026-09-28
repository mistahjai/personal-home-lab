
### NOTE: Username and Password resets to wallabag defaults

# 1. Force install the Wallabag tables and schema
docker compose exec -it wallabag php /var/www/wallabag/bin/console wallabag:install --env=prod --no-interaction

# 2. Ensure all schema migrations are fully up to date
docker compose exec -it wallabag php /var/www/wallabag/bin/console doctrine:migrations:migrate --env=prod --no-interaction
