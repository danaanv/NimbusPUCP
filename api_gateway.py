from flask import Flask, request, jsonify
import requests
from functools import wraps
import jwt

app = Flask(__name__)

# Configuración
AUTH_SERVICE_URL = "http://localhost:5001"  # URL de tu auth.py
JWT_SECRET_KEY = "clave_super_secreta_123"  # DEBE coincidir con auth.py
SERVICE_REGISTRY = {
    'api': 'http://localhost:5002',  # Servicio mock para /api/slices
}

# --- Decorador de autenticación ---
def token_requerido(f):
    @wraps(f)
    def decorador(*args, **kwargs):
        token = None
        auth_header = request.headers.get('Authorization', '')
        
        if auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            
        if not token:
            return jsonify({"error": "Token no proporcionado"}), 401
        
        try:
            # Verificar token con auth.py
            resp = requests.get(
                f"{AUTH_SERVICE_URL}/verify-token",
                headers={"Authorization": f"Bearer {token}"},
                timeout=5
            )
            if resp.status_code != 200:
                return jsonify({"error": "Token inválido"}), 401
            return f(*args, **kwargs)
        except requests.exceptions.RequestException as e:
            return jsonify({"error": f"Error al validar token: {str(e)}"}), 503
    return decorador

# --- Rutas ---
@app.route('/login', methods=['POST'])
def login():
    """Proxy para auth.py"""
    try:
        resp = requests.post(
            f"{AUTH_SERVICE_URL}/login",
            json=request.json
        )
        return (resp.json(), resp.status_code)
    except requests.exceptions.RequestException as e:
        return jsonify({"error": str(e)}), 502

@app.route('/api/slices', methods=['GET'])
@token_requerido
def get_slices():
    """Ejemplo: Ruta protegida con mock"""
    return jsonify({
        "slices": ["sliceA", "sliceB"],
        "message": "¡Funciona! "
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"})

if __name__ == '__main__':
    app.run(port=5005, debug=True)  # Gateway en puerto 5005