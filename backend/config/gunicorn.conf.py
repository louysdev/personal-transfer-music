import multiprocessing

# Server socket
bind = "0.0.0.0:8080"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = 'sync'
timeout = 900

# Worker settings
max_requests = 1000
max_requests_jitter = 50
keepalive = 500 

# Logging
accesslog = '-'
errorlog = '-'
loglevel = 'info'

# Process naming
proc_name = 'spotify-ytm-api'

# Production settings
reload = False
preload_app = True