import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/healthz', methods=['GET'])
def healthz():
    return jsonify({"status": "ok"})

@app.route('/version', methods=['GET'])
def version():
    app_version = os.getenv('APP_VERSION', 'unknown')
    return jsonify({"version": app_version})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)