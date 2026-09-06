#!/bin/bash
echo "🏷️ Tagging..."
docker tag python-service:latest ://amazonaws.com
echo "🚀 Pushing..."
docker push ://amazonaws.com
