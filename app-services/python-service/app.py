from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "status": "healthy",
        "environment": os.getenv("DD_ENV", "local-dev"),
        "message": "Hello from my brand new keyless OIDC pipeline!"
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
