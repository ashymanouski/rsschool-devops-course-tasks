FROM python:3.13-slim

WORKDIR /app

RUN groupadd -r appuser && useradd -r -g appuser appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY code/main.py .

RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

ENV FLASK_APP=main.py

CMD ["flask", "run", "--host=0.0.0.0", "--port=8080"] 