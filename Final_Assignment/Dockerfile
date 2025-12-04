# Use the lightweight Python base
FROM python:3.10-slim

WORKDIR /app

# system deps (if needed)
RUN apt-get update && apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# non-root user (optional)
RUN useradd -m appuser
USER appuser

EXPOSE 5000

# Use gunicorn with 2 workers
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app", "--workers", "2", "--timeout", "60"]
