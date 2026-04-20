from flask import Flask, request, jsonify, send_file
import os
import threading

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(os.path.dirname(BASE_DIR), 'model', 'model.gguf')

app = Flask(__name__)

_llm = None
_llm_loading = False
_llm_lock = threading.Lock()

def load_model():
    global _llm, _llm_loading
    with _llm_lock:
        if _llm is not None:
            return _llm
        _llm_loading = True
        try:
            from llama_cpp import Llama
            print("Indlaeser AI model... (kan tage 30-60 sekunder)")
            _llm = Llama(
                model_path=MODEL_PATH,
                n_ctx=4096,
                n_threads=max(1, os.cpu_count() - 1),
                verbose=False
            )
            print("AI model klar!")
        except Exception as e:
            print(f"Fejl ved indlaesning af model: {e}")
        finally:
            _llm_loading = False
    return _llm

# Indlaes model i baggrunden ved opstart
threading.Thread(target=load_model, daemon=True).start()

@app.route('/')
def index():
    return send_file(os.path.join(BASE_DIR, 'index.html'))

@app.route('/status')
def status():
    return jsonify({
        'model_ready': _llm is not None,
        'model_loading': _llm_loading
    })

@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json(silent=True) or {}
    message = data.get('message', '')

    llm = _llm
    if llm is None:
        if _llm_loading:
            return jsonify({'reply': 'AI modellen indlæses stadig... Vent lidt og prøv igen.'})
        return jsonify({'reply': 'Fejl: AI model ikke fundet. Tjek at model/model.gguf eksisterer.'})

    try:
        response = llm.create_chat_completion(
            messages=[{"role": "user", "content": message}],
            max_tokens=1024,
            temperature=0.7,
        )
        reply = response['choices'][0]['message']['content'].strip()
    except Exception as e:
        reply = f"Fejl under generering: {e}"

    return jsonify({'reply': reply})

if __name__ == '__main__':
    port = 5000
    print(f"ChatRedAI korer pa: http://localhost:{port}")
    print("Tryk Ctrl+C for at stoppe.")
    app.run(host='127.0.0.1', port=port, debug=False)
