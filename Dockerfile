# VidyaSetu Adaptive Learning Platform Container
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all frontend and backend files
COPY . .

# Expose port
EXPOSE 8000

# Start FastAPI server serving both API & Frontend
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
