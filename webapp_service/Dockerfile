FROM python:3.9-slim

WORKDIR /app

# Instalar dependencias del sistema para mysqlclient
RUN apt-get update && apt-get install -y \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements e instalar dependencias Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar aplicación
COPY . .

EXPOSE 5000

# Usar gunicorn para producción
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "run:app"]