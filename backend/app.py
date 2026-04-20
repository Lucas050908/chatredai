from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    message = data.get("message", "")
    reply = f"Du skrev: {message}"
    return jsonify({"reply": reply})

if __name__ == "__main__":
    app.run(port=5000)