FROM nginx:alpine

# Copiar configuración
COPY nginx.conf /etc/nginx/nginx.conf

# Generar certificados SSL automáticamente
RUN apk add --no-cache openssl && \
    mkdir -p /etc/nginx/certs && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/certs/nginx.key \
    -out /etc/nginx/certs/nginx.crt \
    -subj "/C=CO/ST=Valle/L=Cali/O=JeanEsg/CN=192.168.50.3" && \
    chmod 644 /etc/nginx/certs/nginx.crt && \
    chmod 600 /etc/nginx/certs/nginx.key

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]