from datetime import datetime, timedelta
import jwt
import bcrypt
from flask import Flask, jsonify, request
import mysql.connector  
import os

app = Flask(__name__)
app.config['JWT_SECRET_KEY'] = "clave_super_secreta_123"

JWT_SECRET_KEY = "clave_super_secreta_123"

def obtener_conexion_db():
    return mysql.connector.connect(
        host=os.environ.get('DB_HOST', 'localhost'),
        user=os.environ.get('DB_USER', 'root'),
        password=os.environ.get('DB_PASSWORD', 'hemmo1996'),
        database=os.environ.get('DB_NAME', 'infraestructura_cloud')
    )

def generar_token(usuario):
    payload = {
        'id': usuario['id'],
        'username': usuario['username'],
        'rol': usuario['rol'],
        'exp': datetime.utcnow() + timedelta(hours=24)
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm="HS256")

# Función para verificar el token
def verificar_token(token):
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=["HS256"])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

@app.route('/login', methods=['POST'])
def login():
    auth_data = request.get_json()
    username = auth_data.get('username')
    password = auth_data.get('password')
    
    if not username or not password:
        return jsonify({'error': 'Se requieren nombre de usuario y contrasena'}), 400
    
    try:
        conn = obtener_conexion_db()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute(
            "SELECT id, username, password, rol FROM usuarios WHERE username = %s",
            (username,)
        )
        
        usuario_db = cursor.fetchone()
        cursor.close()
        conn.close()
        
        # si no hay usuario 
        if not usuario_db:
            return jsonify({'error': 'Credenciales invalidas'}), 401
            
        # verifica contrasena 
        if bcrypt.checkpw(password.encode('utf-8'), usuario_db['password'].encode('utf-8')):
            # Crear objeto de usuario sin incluir  passqword
            usuario = {
                'id': usuario_db['id'],
                'username': usuario_db['username'],
                'rol': usuario_db['rol']
            }
            return jsonify({
                'token': generar_token(usuario),
                'usuario': usuario
            })
        
        return jsonify({'error': 'Credenciales invalidas'}), 401
        
    except Exception as e:
        return jsonify({'error': f'Error en el servidor: {str(e)}'}), 500

# Nueva ruta para verificar token
@app.route('/verify-token', methods=['GET'])
def verify_token():
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return jsonify({'error': 'Token no proporcionado correctamente'}), 401
    
    token = auth_header.split(' ')[1]
    payload = verificar_token(token)
    
    if payload:
        return jsonify({'valid': True, 'user': payload}), 200
    else:
        return jsonify({'error': 'Token inválido o expirado'}), 401

if __name__ == '__main__':
    app.run(debug=True, port=5001)