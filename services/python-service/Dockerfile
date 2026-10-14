FROM python:3.12-alpine
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py ./
USER nobody
EXPOSE 8086
CMD ["python", "main.py"]
