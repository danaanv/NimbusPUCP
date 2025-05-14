from datetime import datetime, timedelta
import jwt
import bcrypt
from flask import Flask, jsonify, request
import mysql.connector  
import os
import requests

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
    
def login_cli():
    print("\n=== Login CLI ===")
    username = input("Usuario: ")
    password = input("Contraseña: ")

    try:
        response = requests.post(
            "http://localhost:5001/login",
            json={"username": username, "password": password},
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            data = response.json()
            print("\n Login exitoso!")
            print(f"Token: {data['token']}")
            print(f"Usuario: {data['usuario']['username']}")
            print(f"Rol: {data['usuario']['rol']}")
        else:
            print(f"\n Error: {response.json().get('error', 'Credenciales inválidas')}")

    except Exception as e:
        print(f"\n Error de conexión: {str(e)}")

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == '--cli':
        login_cli()
    else:
        app.run(debug=True, port=5001)