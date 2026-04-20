from flask import Flask, request, jsonify, send_file
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

app = Flask(__name__)

@app.route('/')
def index():
    return send_file(os.path.join(BASE_DIR, 'index.html'))

@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json(silent=True) or {}
    message = data.get('message', '')
    reply = f"Du skrev: {message}"
    return jsonify({'reply': reply})

if __name__ == '__main__':
    port = 5000
    print(f"ChatRedAI korer pa: http://localhost:{port}")
    print("Tryk Ctrl+C for at stoppe serveren.")
    app.run(host='127.0.0.1', port=port, debug=False)
