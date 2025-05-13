from datetime import datetime, timedelta
import jwt
import bcrypt
from flask import jsonify, request
from config import JWT_SECRET_KEY
import mysql.connector  # O cualquier otro conector de base de datos

def obtener_conexion_db():
    # Estos valores deberían estar en variables de entorno
    return mysql.connector.connect(
        host=os.environ.get('DB_HOST', 'localhost'),
        user=os.environ.get('DB_USER', 'usuario_app'),
        password=os.environ.get('DB_PASSWORD', ''),
        database=os.environ.get('DB_NAME', 'mi_aplicacion')
    )

def generar_token(usuario):
    payload = {
        'id': usuario['id'],
        'username': usuario['username'],
        'rol': usuario['rol'],
        'exp': datetime.utcnow() + timedelta(hours=24)
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm="HS256")

def login():
    auth_data = request.get_json()
    username = auth_data.get('username')
    password = auth_data.get('password')
    
    if not username or not password:
        return jsonify({'error': 'Se requieren nombre de usuario y contraseña'}), 400
    
    try:
        conn = obtener_conexion_db()
        cursor = conn.cursor(dictionary=True)
        
        # Consulta segura usando parámetros para evitar inyección SQL
        cursor.execute(
            "SELECT id, username, password_hash, rol FROM usuarios WHERE username = %s",
            (username,)
        )
        
        usuario_db = cursor.fetchone()
        cursor.close()
        conn.close()
        
        # si no hay usuario 
        if not usuario_db:
            return jsonify({'error': 'Credenciales inválidas'}), 401
            
        # verifica contrasena 
        if bcrypt.checkpw(password.encode('utf-8'), usuario_db['password_hash'].encode('utf-8')):
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
        
        return jsonify({'error': 'Credenciales inválidas'}), 401
        
    except Exception as e:
        return jsonify({'error': f'Error en el servidor: {str(e)}'}), 500