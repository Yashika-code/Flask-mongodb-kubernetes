# app.py
from flask import Flask, request, jsonify
from pymongo import MongoClient
from datetime import datetime
import os
import urllib.parse

app = Flask(__name__)

# Environment-driven configuration (set these in k8s Secret / env)
MONGO_USER = os.environ.get("MONGO_INITDB_ROOT_USERNAME", "root")
MONGO_PASS = os.environ.get("MONGO_INITDB_ROOT_PASSWORD", "example")
MONGO_HOST = os.environ.get("MONGO_HOST", "mongodb")
MONGO_PORT = os.environ.get("MONGO_PORT", "27017")
MONGO_DB = os.environ.get("MONGO_DB", "flask_db")

# Build MongoDB URI using auth (authSource=admin)
user_enc = urllib.parse.quote_plus(MONGO_USER)
pass_enc = urllib.parse.quote_plus(MONGO_PASS)
MONGO_URI = os.environ.get("MONGODB_URI",
                           f"mongodb://{user_enc}:{pass_enc}@{MONGO_HOST}:{MONGO_PORT}/?authSource=admin")

client = MongoClient(MONGO_URI)
db = client[MONGO_DB]
collection = db.data

@app.route("/")
def index():
    return f"Welcome to the Flask app! The current time is: {datetime.now()}"

@app.route("/data", methods=["GET", "POST"])
def data():
    if request.method == "POST":
        payload = request.get_json(force=True, silent=True)
        if not payload:
            return jsonify({"error": "Invalid JSON or empty body"}), 400
        # Optionally add timestamp
        payload["_inserted_at"] = datetime.utcnow().isoformat()
        collection.insert_one(payload)
        return jsonify({"status": "Data inserted"}), 201
    else:
        # GET - return documents (hide _id)
        docs = list(collection.find({}, {"_id": 0}))
        return jsonify(docs), 200

if __name__ == "__main__":
    # Use 0.0.0.0 for container networking; port 5000
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
