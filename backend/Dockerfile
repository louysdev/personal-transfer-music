FROM python:3.11-slim

WORKDIR /app

# Install system dependencies if any needed (usually none for these python packages)
# RUN apt-get update && apt-get install -y ...

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Expose the port
EXPOSE 8000

# Run the application
CMD ["gunicorn", "main:app", "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "120"]
