FROM python:3.10-slim

WORKDIR /app
COPY . /app

RUN pip install .

EXPOSE 8080

CMD ["python3", "-m", "analytics_mcp"]
