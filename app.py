from flask import Flask, jsonify, request
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from pymongo.errors import ServerSelectionTimeoutError, ConnectionFailure
from dotenv import load_dotenv
from datetime import datetime
import os

# Load environment variables
load_dotenv()

app = Flask(__name__)

# MongoDB configuration
MONGODB_URI = os.getenv('MONGODB_URI', 'mongodb://localhost:27017/')
MONGODB_USERNAME = os.getenv('MONGODB_USERNAME', '')
MONGODB_PASSWORD = os.getenv('MONGODB_PASSWORD', '')
DB_NAME = os.getenv('MONGO_INITDB_DATABASE', 'flask_db')
COLLECTION_NAME = os.getenv('MONGO_COLLECTION_NAME', 'data')

# Global database connection objects
client = None
db = None
collection = None

def build_mongodb_uri():
    """Build MongoDB URI with authentication if credentials are provided."""
    base_uri = MONGODB_URI
    
    # If credentials are provided and URI doesn't already have them
    if MONGODB_USERNAME and MONGODB_PASSWORD:
        if '://' in base_uri:
            scheme, rest = base_uri.split('://', 1)
            # Avoid duplicate credentials
            if '@' not in rest:
                base_uri = f"{scheme}://{MONGODB_USERNAME}:{MONGODB_PASSWORD}@{rest}"
    
    return base_uri

def connect_to_mongodb():
    """Initialize MongoDB connection with proper error handling."""
    global client, db, collection
    
    try:
        connection_uri = build_mongodb_uri()
        print(f"Attempting to connect to MongoDB...")
        print(f"Database: {DB_NAME}, Collection: {COLLECTION_NAME}")
        
        client = MongoClient(
            connection_uri,
            server_api=ServerApi('1'),
            serverSelectionTimeoutMS=5000,
            connectTimeoutMS=10000,
            retryWrites=True
        )
        
        # Test the connection
        client.admin.command('ping')
        db = client[DB_NAME]
        collection = db[COLLECTION_NAME]
        
        print("✅ Successfully connected to MongoDB!")
        return True
        
    except (ServerSelectionTimeoutError, ConnectionFailure) as e:
        print(f"❌ MongoDB Connection Timeout: {e}")
        print("Please ensure MongoDB is running and the URI is correct.")
        return False
    except Exception as e:
        print(f"❌ MongoDB Connection Error: {e}")
        return False

# Connect to MongoDB on startup
if not connect_to_mongodb():
    print("⚠️ Warning: Application starting without MongoDB connection")

@app.route('/')
def home():
    """Home endpoint to return welcome message with current time."""
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return f"Welcome to the Flask app! The current time is: {current_time}"

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for Docker."""
    if client is not None and collection is not None:
        try:
            client.admin.command('ping')
            return jsonify({"status": "healthy", "database": "connected"}), 200
        except Exception as e:
            return jsonify({"status": "unhealthy", "error": str(e)}), 500
    return jsonify({"status": "unhealthy", "database": "not connected"}), 503

@app.route('/data', methods=['GET', 'POST'])
def handle_data():
    """Handle data insertion and retrieval."""
    if collection is None:
        return jsonify({
            "error": "Database not connected",
            "message": "MongoDB connection failed"
        }), 503
    
    if request.method == 'POST':
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400
        
        try:
            result = collection.insert_one(data)
            return jsonify({
                "status": "Data inserted",
                "id": str(result.inserted_id)
            }), 201
        except Exception as e:
            return jsonify({"error": f"Failed to insert data: {str(e)}"}), 500
    
    # GET request - retrieve all data
    try:
        items = list(collection.find({}, {'_id': 0}))
        return jsonify(items), 200
    except Exception as e:
        return jsonify({"error": f"Failed to retrieve data: {str(e)}"}), 500

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return jsonify({"error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)