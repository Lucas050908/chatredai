from flask import Flask, request, jsonify, send_file
import os
import subprocess
import threading
import time
import urllib.request
import json

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(BASE_DIR)
MODEL_PATH = os.path.join(ROOT_DIR, 'model', 'model.gguf')
LLAMA_EXE = os.path.join(ROOT_DIR, 'llama', 'llama-server.exe')
LLAMA_PORT = 8080

app = Flask(__name__)
_server_proc = None
_server_ready = False

def start_llama_server():
    global _server_proc, _server_ready
    if not os.path.exists(LLAMA_EXE):
        print("FEJL: llama-server.exe ikke fundet i llama/ mappen")
        return
    if not os.path.exists(MODEL_PATH):
        print("FEJL: model.gguf ikke fundet i model/ mappen")
        return

    threads = max(1, (os.cpu_count() or 4) - 1)
    print(f"Starter llama-server med {threads} tråde...")
    _server_proc = subprocess.Popen(
        [LLAMA_EXE, '-m', MODEL_PATH,
         '--port', str(LLAMA_PORT),
         '--ctx-size', '4096',
         '-t', str(threads),
         '--no-mmap'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    # Vent på serveren er klar
    for _ in range(60):
        time.sleep(2)
        try:
            urllib.request.urlopen(f'http://localhost:{LLAMA_PORT}/health', timeout=2)
            _server_ready = True
            print("AI server klar!")
            return
        except:
            pass
    print("Advarsel: AI server startede ikke inden for 2 minutter")

threading.Thread(target=start_llama_server, daemon=True).start()

@app.route('/')
def index():
    return send_file(os.path.join(BASE_DIR, 'index.html'))

@app.route('/status')
def status():
    return jsonify({'model_ready': _server_ready})

@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json(silent=True) or {}
    message = data.get('message', '')

    if not _server_ready:
        if not os.path.exists(MODEL_PATH):
            return jsonify({'reply': 'Fejl: model.gguf mangler i model/ mappen.'})
        return jsonify({'reply': 'AI modellen starter... vent lidt og prøv igen.'})

    try:
        payload = json.dumps({
            'messages': [{'role': 'user', 'content': message}],
            'max_tokens': 1024,
            'temperature': 0.7,
        }).encode('utf-8')
        req = urllib.request.Request(
            f'http://localhost:{LLAMA_PORT}/v1/chat/completions',
            data=payload,
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode('utf-8'))
            reply = result['choices'][0]['message']['content'].strip()
    except Exception as e:
        reply = f'Fejl: {e}'

    return jsonify({'reply': reply})

if __name__ == '__main__':
    print(f"ChatRedAI korer pa: http://localhost:5000")
    print("Tryk Ctrl+C for at stoppe.")
    app.run(host='127.0.0.1', port=5000, debug=False)
