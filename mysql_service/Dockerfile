FROM mysql:8.0

# Copiar script de inicialización
COPY init.sql /docker-entrypoint-initdb.d/

# Configuración de MySQL
ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=myflaskapp

EXPOSE 3306