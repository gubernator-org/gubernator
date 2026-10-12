part of '../compose_studio_page.dart';

const String _defaultTemplate = '''services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    labels:
      - "ingress.host=app.gbnt.local"
      - "gbnt.caddy.port=80"
      - "gbnt.node.role=worker"
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
''';

const Map<String, String> _starterTemplates = {
    'Autoscaling GPU AI Inference Stack': '''services:
  inference:
    image: vllm/vllm-openai:latest
    ports:
      - "8000:8000"
    labels:
      - "ingress.host=ai.gbnt.local"
      - "gbnt.caddy.port=8000"
      - "gbnt.caddy.lb=round_robin"
      - "gbnt.placement.strategy=spread"
      - "gbnt.node.gpu=nvidia"
      - "gbnt.autoscaling.enable=true"
      - "gbnt.autoscaling.metric=gpu"
      - "gbnt.autoscaling.scope=cluster"
      - "gbnt.autoscaling.target=80"
      - "gbnt.autoscaling.min=1"
      - "gbnt.autoscaling.max=4"
      - "gbnt.autoscaling.cooldown=60s"
    deploy:
      replicas: 1
''',
    'Multi-Host Load Balanced Web': '''services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    labels:
      - "ingress.host=multi-web.gbnt.local"
      - "gbnt.caddy.port=8080"
      - "gbnt.caddy.lb=round_robin"
      - "gbnt.caddy.health_uri=/"
      - "gbnt.placement.strategy=spread"
      - "gbnt.node.role=worker"
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
''',
    'Multi-Host Server Echo': r'''services:
  echo:
    image: python:3.11-alpine
    restart: unless-stopped
    volumes:
      - /etc/hostname:/etc/host_hostname:ro
    ports:
      - "8080:8080"
    labels:
      - "ingress.host=echo.gbnt.local"
      - "gbnt.caddy.lb=round_robin"
      - "gbnt.caddy.health_uri=/health"
      - "gbnt.placement.strategy=spread"
    deploy:
      replicas: 3
      placement:
        preferences:
          - spread: node.id
    command:
      - python3
      - -c
      - |
        import os, socket, json, time
        from http.server import HTTPServer, BaseHTTPRequestHandler
        req_count = 0
        class H(BaseHTTPRequestHandler):
            def do_GET(self):
                global req_count; req_count += 1
                if self.path == '/health':
                    self.send_response(200); self.end_headers(); self.wfile.write(b'OK'); return
                nid = os.environ.get('GBNT_NODE_ID', '')
                if not nid:
                    try: nid = open('/etc/host_hostname').read().strip()
                    except: nid = 'unknown'
                nip = os.environ.get('GBNT_NODE_IP', 'unknown')
                cid = socket.gethostname()
                body = f"🏛️ Gubernator Multi-Host Ingress\nCenturion Node: {nid}\nNode IP:        {nip}\nContainer ID:   {cid}\nRequest:        #{req_count}\n"
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain; charset=utf-8')
                self.end_headers()
                self.wfile.write(body.encode('utf-8'))
        HTTPServer(('0.0.0.0', 8080), H).serve_forever()
''',
    'Protected Web Ingress (WAF)': '''services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    labels:
      - "ingress.host=secure-web.gbnt.local"
      - "gbnt.caddy.port=80"
      - "gbnt.waf.enabled=true"
      - "gbnt.waf.mode=enforce"
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
''',
    'Web Ingress': '''services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    labels:
      - "ingress.host=web.gbnt.local"
      - "gbnt.caddy.port=80"
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
''',
    'Postgres Storage': '''services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: gubernator
      POSTGRES_PASSWORD: secretpassword
    volumes:
      - /var/contenedores/\${STACK_NAME}/pgdata:/var/lib/postgresql/data
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
        reservations:
          cpus: "0.5"
          memory: 512M
''',
    'SRE Monitored Microservice': '''services:
  api:
    image: python:3.11-slim
    command: python -m http.server 8080
    ports:
      - "8080:8080"
    labels:
      - "ingress.host=api.gbnt.local"
      - "gbnt.caddy.port=8080"
      - "gbnt.slo.enable=true"
      - "gbnt.slo.target=99.9"
      - "gbnt.slo.window=30d"
      - "gbnt.slo.indicator=latency"
      - "gbnt.slo.latency.threshold=200ms"
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
''',
    'Gatekeeper Signed App': '''services:
  secure-app:
    image: redis:alpine
    labels:
      - "ingress.host=hardened.gbnt.local"
      - "gbnt.caddy.port=6379"
      - "gbnt.waf.enabled=true"
      - "gbnt.waf.mode=enforce"
      - "gbnt.security.require-signature=true"
      - "gbnt.security.max-cve-severity=critical"
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
''',
    'GPU / AI Task': '''services:
  llm-worker:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - /var/contenedores/\${STACK_NAME}/models:/root/.ollama
    labels:
      - "gbnt.node.gpu=nvidia"
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "4.0"
          memory: 8G
        reservations:
          cpus: "2.0"
          memory: 2G
''',
    'JupyterLab PyTorch LLM': '''services:
  jupyter-llm:
    image: quay.io/jupyter/pytorch-notebook:latest
    container_name: jupyter_llm_lab
    restart: unless-stopped
    ports:
      - "127.0.0.1::8888"
    environment:
      - JUPYTER_TOKEN=gubernator-secret
      - JUPYTER_ENABLE_LAB=yes
    volumes:
      - /var/contenedores/jupyter-llm/work:/home/jovyan/work
      - /var/contenedores/jupyter-llm/hf_cache:/home/jovyan/.cache/huggingface
    labels:
      - "ingress.host=jupyter-llm.gbnt.local"
      - "gbnt.caddy.port=8888"
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "4.0"
          memory: 8G
        reservations:
          cpus: "1.0"
          memory: 2G
''',
    'LLaMA-Factory Studio': '''services:
  llama-factory:
    image: hiyouga/llamafactory:latest
    container_name: llama_factory_studio
    restart: unless-stopped
    ports:
      - "127.0.0.1::7860"
    environment:
      - GRADIO_SERVER_NAME=0.0.0.0
      - GRADIO_SERVER_PORT=7860
    volumes:
      - /var/contenedores/llama-factory/data:/app/data
      - /var/contenedores/llama-factory/saves:/app/saves
      - /var/contenedores/llama-factory/output:/app/output
      - /var/contenedores/llama-factory/hf_cache:/root/.cache/huggingface
    labels:
      - "ingress.host=llama-factory.gbnt.local"
      - "gbnt.caddy.port=7860"
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "4.0"
          memory: 12G
        reservations:
          cpus: "1.0"
          memory: 4G
''',
    'Kubeflow MLOps Platform': '''services:
  minio:
    image: minio/minio:latest
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=kubeflow
      - MINIO_ROOT_PASSWORD=gubernator123
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - /var/contenedores/kubeflow/minio_data:/data
    labels:
      - "ingress.host=minio.kubeflow.gbnt.local"
      - "gbnt.caddy.port=9001"
      - "gbnt.service.name=minio-s3"
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "1.0"
          memory: 2G
        reservations:
          cpus: "0.25"
          memory: 512M

  mlflow:
    image: ghcr.io/mlflow/mlflow:latest
    restart: unless-stopped
    command: mlflow server --host 0.0.0.0 --port 5000 --workers 1 --allowed-hosts "*" --backend-store-uri sqlite:////data/mlflow.db --default-artifact-root s3://mlflow-artifacts/
    environment:
      - AWS_ACCESS_KEY_ID=kubeflow
      - AWS_SECRET_ACCESS_KEY=gubernator123
      - MLFLOW_S3_ENDPOINT_URL=http://minio.kubeflow.gbnt.local
      - MLFLOW_S3_IGNORE_TLS=true
      - MLFLOW_ALLOWED_HOSTS=*
    ports:
      - "5000:5000"
    volumes:
      - /var/contenedores/kubeflow/mlflow_data:/data
    labels:
      - "ingress.host=mlflow.kubeflow.gbnt.local"
      - "gbnt.caddy.port=5000"
      - "gbnt.service.name=mlflow-tracking"
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
        reservations:
          cpus: "0.5"
          memory: 512M

  jupyter-workspace:
    image: quay.io/jupyter/pytorch-notebook:latest
    restart: unless-stopped
    environment:
      - JUPYTER_TOKEN=gubernator-secret
      - JUPYTER_ENABLE_LAB=yes
      - AWS_ACCESS_KEY_ID=kubeflow
      - AWS_SECRET_ACCESS_KEY=gubernator123
      - MLFLOW_TRACKING_URI=http://mlflow.kubeflow.gbnt.local
      - MLFLOW_S3_ENDPOINT_URL=http://minio.kubeflow.gbnt.local
    ports:
      - "8888:8888"
    volumes:
      - /var/contenedores/kubeflow/workspaces:/home/jovyan/work
      - /var/contenedores/kubeflow/cache:/home/jovyan/.cache
    labels:
      - "ingress.host=notebooks.kubeflow.gbnt.local"
      - "gbnt.caddy.port=8888"
      - "gbnt.service.name=jupyterlab"
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "2.0"
          memory: 4G
        reservations:
          cpus: "0.5"
          memory: 1G

  inference-engine:
    image: ollama/ollama:latest
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - /var/contenedores/kubeflow/models:/root/.ollama
    labels:
      - "ingress.host=inference.kubeflow.gbnt.local"
      - "gbnt.caddy.port=11434"
      - "gbnt.service.name=model-serving"
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: "2.0"
          memory: 4G
        reservations:
          cpus: "0.5"
          memory: 1G
''',
    'DeepSeek & vLLM Inference': '''services:
  vllm-engine:
    image: vllm/vllm-openai:latest
    restart: unless-stopped
    command: >
      --model deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B
      --port 8000
      --max-model-len 4096
    ports:
      - "8000:8000"
    volumes:
      - /var/contenedores/vllm/models:/root/.cache/huggingface
    labels:
      - "ingress.host=api.deepseek.gbnt.local"
      - "gbnt.caddy.port=8000"
    deploy:
      resources:
        limits:
          cpus: "4.0"
          memory: 8G
        reservations:
          cpus: "1.0"
          memory: 4G

  chat-ui:
    image: ghcr.io/open-webui/open-webui:main
    restart: unless-stopped
    environment:
      - OPENAI_API_BASE_URL=http://api.deepseek.gbnt.local:8000/v1
      - WEBUI_AUTH=False
    ports:
      - "8080:8080"
    volumes:
      - /var/contenedores/open-webui/data:/app/backend/data
    labels:
      - "ingress.host=chat.deepseek.gbnt.local"
      - "gbnt.caddy.port=8080"
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 1G
        reservations:
          cpus: "0.2"
          memory: 256M
''',
    'GenAI RAG Search (pgvector)': '''services:
  postgres-vector:
    image: pgvector/pgvector:pg16
    restart: unless-stopped
    environment:
      - POSTGRES_DB=ragdb
      - POSTGRES_USER=raguser
      - POSTGRES_PASSWORD=gubernator-secret
    ports:
      - "5432:5432"
    volumes:
      - /var/contenedores/pgvector/data:/var/lib/postgresql/data
    labels:
      - "ingress.host=postgres.rag.gbnt.local"
      - "gbnt.caddy.port=5432"
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
        reservations:
          cpus: "0.25"
          memory: 512M

  qdrant:
    image: qdrant/qdrant:latest
    restart: unless-stopped
    ports:
      - "6333:6333"
    volumes:
      - /var/contenedores/qdrant/storage:/qdrant/storage
    labels:
      - "ingress.host=qdrant.rag.gbnt.local"
      - "gbnt.caddy.port=6333"
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
        reservations:
          cpus: "0.25"
          memory: 512M

  rag-ui:
    image: ghcr.io/open-webui/open-webui:main
    restart: unless-stopped
    environment:
      - WEBUI_AUTH=False
      - VECTOR_DB=qdrant
      - QDRANT_HOST=qdrant.rag.gbnt.local
      - QDRANT_PORT=6333
    ports:
      - "8080:8080"
    volumes:
      - /var/contenedores/rag-ui/data:/app/backend/data
    labels:
      - "ingress.host=search.rag.gbnt.local"
      - "gbnt.caddy.port=8080"
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 1G
        reservations:
          cpus: "0.2"
          memory: 256M
''',
    'Kafka & ClickHouse Analytics': '''services:
  kafka:
    image: apache/kafka:3.7.0
    restart: unless-stopped
    environment:
      - KAFKA_NODE_ID=1
      - KAFKA_PROCESS_ROLES=broker,controller
      - KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka.analytics.gbnt.local:9092
      - KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      - KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka.analytics.gbnt.local:9093
      - KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1
    ports:
      - "9092:9092"
    volumes:
      - /var/contenedores/kafka/data:/tmp/kraft-combined-logs
    labels:
      - "ingress.host=kafka.analytics.gbnt.local"

  clickhouse:
    image: clickhouse/clickhouse-server:latest
    restart: unless-stopped
    ports:
      - "8123:8123"
    volumes:
      - /var/contenedores/clickhouse/data:/var/lib/clickhouse
    labels:
      - "ingress.host=clickhouse.analytics.gbnt.local"
      - "gbnt.caddy.port=8123"

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    restart: unless-stopped
    environment:
      - KAFKA_CLUSTERS_0_NAME=gbnt-cluster
      - KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=kafka.analytics.gbnt.local:9092
    ports:
      - "8080:8080"
    labels:
      - "ingress.host=ui.analytics.gbnt.local"
      - "gbnt.caddy.port=8080"
''',
};
