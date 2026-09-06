# Step 1: Use a lightweight official Python image
FROM python:3.12-slim

# Step 2: Set the working directory inside the container
WORKDIR /app

# Step 3: Copy and install python application dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Step 4: Copy the application script code
COPY app.py .

# Step 5: Open up the networking port
EXPOSE 8080

# Step 6: Start the application execution runtime
CMD ["python", "app.py"]
