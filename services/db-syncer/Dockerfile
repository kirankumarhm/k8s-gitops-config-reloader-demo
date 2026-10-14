FROM python:3.12-alpine
WORKDIR /app
RUN apk add --no-cache libpq
COPY requirements.txt ./
RUN apk add --no-cache --virtual .build-deps gcc musl-dev postgresql-dev && \
    pip install --no-cache-dir -r requirements.txt && \
    apk del .build-deps
COPY syncer.py ./
CMD ["python", "syncer.py"]
