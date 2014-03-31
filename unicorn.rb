worker_processes 32
preload_app true
timeout 30
listen 3000

stderr_path "/var/app/philomela/log/stderr.log"
stdout_path "/var/app/philomela/log/stdout.log"