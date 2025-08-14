FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY services/ ./services/

EXPOSE 8080

CMD ["uvicorn", "services.data_loader.main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "2"]
