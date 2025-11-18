from prometheus_client import Counter, Histogram, Gauge

# ===================================
# MÉTRICAS DE PROMETHEUS
# ===================================

http_requests_total = Counter(
    'flask_http_requests_total',
    'Total de peticiones HTTP',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'flask_http_request_duration_seconds',
    'Duración de las peticiones HTTP en segundos',
    ['method', 'endpoint']
)

active_connections = Gauge(
    'flask_active_connections',
    'Número de conexiones activas'
)

app_info = Gauge(
    'flask_app_info',
    'Información de la aplicación',
    ['version', 'environment']
)

crud_operations_total = Counter(
    'flask_crud_operations_total',
    'Total de operaciones CRUD',
    ['operation', 'table']
)


def track_crud_operation(operation, table):
    """Registrar operaciones CRUD"""
    crud_operations_total.labels(operation=operation, table=table).inc()
