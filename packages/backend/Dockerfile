# Stage 1: Builder stage to install dependencies
FROM python:3.11-slim as builder

WORKDIR /app

# Create a virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements and install dependencies into the virtual environment
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

# Stage 2: Final application stage
FROM python:3.11-slim

WORKDIR /app

# Copy the virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv

# Copy the application source code
COPY . .

# Make port 8080 available
EXPOSE 8080

# Set the path to include the virtual environment's binaries
ENV PATH="/opt/venv/bin:$PATH"

# Run the application with Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
