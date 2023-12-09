from flask import Flask, request, jsonify, render_template, redirect, url_for, session, flash   
from flask_cors import CORS
import mysql.connector
from werkzeug.utils import secure_filename
import os

UPLOAD_FOLDER = os.path.abspath(os.path.join(os.path.dirname(__file__), 'static', 'uploads'))
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app =Flask(__name__)
app.secret_key = '21752583'

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Configuración de la base de datos
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': '',
    'database': 'app_tfi',
}

# Conexión a la base de datos
connection = mysql.connector.connect(**db_config)
cursor = connection.cursor(dictionary=True)
create_table_query = """
        CREATE TABLE usuarios (
            id INT AUTO_INCREMENT PRIMARY KEY,
            correo VARCHAR(255) NOT NULL,
            contrasena VARCHAR(255) NOT NULL,
            rol ENUM('usuario', 'admin') DEFAULT 'usuario',
            usuario VARCHAR(255) NOT NULL
        );
        """
cursor.execute(create_table_query)
connection.commit()
#Rutas
@app.route("/")
def index():
    return render_template('login.html')

@app.route('/login', methods=['POST'])
def login():
    user = request.form['user']
    password = request.form['password']

    query = "SELECT id, rol FROM usuarios WHERE usuario = %s AND contrasena = %s"
    cursor.execute(query, (user, password))
    usuario = cursor.fetchone()


    if usuario and usuario['rol']:  # Verifica si la consulta devolvió resultados y el rol no está vacío
        session['id'] = usuario['id']
        session['rol'] = usuario['rol']  # Configura session['rol']
        print("Redireccionando a admin_dashboard" if usuario['rol'] == 'admin' else "Redireccionando a user_dashboard")
        if usuario['rol'] == 'admin':
            return redirect(url_for('admin_dashboard'))
        else:
            return redirect(url_for('user_dashboard'))
    
@app.route('/admin/dashboard')
def admin_dashboard():
    if 'id' in session:
        cursor.execute('SELECT * FROM productos')
        productos = cursor.fetchall()
        return render_template('panel_admin.html', productos=productos)
    else:
        return redirect(url_for('index'))

@app.route('/user/dashboard')
def user_dashboard():
    if 'id' in session:
        cursor.execute('SELECT * FROM productos')
        productos = cursor.fetchall()
        return render_template('show.html', productos=productos)
    else:
        return redirect(url_for('index'))
    
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        nombre = request.form['nombre']
        correo = request.form['correo']
        contrasena = request.form['contrasena']


        # Verificar si el nombre de usuario ya está en uso
        query_verificar_nombre = "SELECT id FROM usuarios WHERE usuario = %s"
        cursor.execute(query_verificar_nombre, (nombre,))
        if cursor.fetchone():
            flash("¡El nombre de usuario ya está en uso! Por favor, elige otro.", 'warning')
            return redirect(url_for('register'))

        # Verificar si el correo ya está en uso
        query_verificar_correo = "SELECT id FROM usuarios WHERE correo = %s"
        cursor.execute(query_verificar_correo, (correo,))
        if cursor.fetchone():
            flash("¡La dirección de correo electrónico ya está en uso! Intenta con otra.", 'warning')
            return redirect(url_for('register'))

        # Insertar nuevo usuario en la base de datos
        query_insertar_usuario = "INSERT INTO usuarios (usuario, correo, contrasena) VALUES (%s, %s, %s)"
        cursor.execute(query_insertar_usuario, (nombre, correo, contrasena))
        connection.commit()

        flash("Registro exitoso, ahora puedes iniciar sesion", 'success')
        return redirect(url_for('index'))

    return render_template('register.html')

@app.route('/logout')
def logout():
    session.clear()  # Limpiar todos los datos de la sesión
    return redirect(url_for('show'))

@app.route('/show')
def show():
    rol_usuario = session.get('rol')  # Utiliza get para evitar excepciones si la clave no está presente
    print("Rol del usuario:", rol_usuario)
    cursor.execute('SELECT * FROM productos')
    productos = cursor.fetchall()
    return render_template('show.html', productos=productos)

@app.route('/crear_producto', methods=['GET', 'POST'])
def crear_producto():
    if request.method == 'POST':
        codigo = request.form['codigo']
        descripcion = request.form['descripcion']
        precio = request.form['precio']
        imagen = request.files['imagen']
        stock = request.form['stock']
        # Verifica si el producto con el mismo código ya existe en la base de datos
        cursor.execute('SELECT * FROM productos WHERE codigo = %s', (codigo,))
        existing_product = cursor.fetchone()
        
        if existing_product:
            # Si ya existe un producto con el mismo código, muestra un mensaje de alerta
            flash("¡Error! Ya existe un producto con el mismo código.", 'error')
            return redirect(url_for('crear_producto'))
        
        if imagen and allowed_file(imagen.filename):
            filename = secure_filename(imagen.filename)
            file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            print("Guardando archivo en:", file_path)
            imagen.save(file_path)
            imagen_url = os.path.join('uploads', filename)
        else:
            # Si no se proporciona una imagen válida, establece file_path en None
            file_path = None
            imagen_url = None

        print("Guardando archivo en:", file_path)  # Agregado para depuración

        cursor.execute('''
            INSERT INTO productos (codigo, descripcion, precio, imagen_url, stock)
            VALUES (%s, %s, %s, %s, %s)
        ''', (codigo, descripcion, precio, imagen_url.replace('\\', '/'), stock))
        connection.commit()

        return redirect(url_for('admin_dashboard'))

    return render_template('crear_producto.html')

@app.route('/editar_producto/<int:codigo>', methods=['GET', 'POST'])
def editar_producto(codigo):
    # Obtener información del producto
    cursor.execute('SELECT * FROM productos WHERE codigo = %s', (codigo,))
    producto = cursor.fetchone()

    if request.method == 'POST':
        # Obtener los valores del formulario
        descripcion = request.form['descripcion']
        stock = request.form['stock']
        nueva_imagen = request.files['nueva_imagen']

        # Verificar si se proporcionó una nueva imagen
        if nueva_imagen and allowed_file(nueva_imagen.filename):
            filename = secure_filename(nueva_imagen.filename)
            file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            nueva_imagen.save(file_path)
            imagen_url = os.path.join('uploads', filename)
        else:
            # Si no se proporciona una nueva imagen, mantener la imagen existente
            imagen_url = producto['imagen_url']

        # Actualizar la información del producto en la base de datos
        cursor.execute('''
            UPDATE productos
            SET descripcion = %s, stock = %s, imagen_url = %s
            WHERE codigo = %s
        ''', (descripcion, stock, imagen_url.replace('\\', '/'), codigo))
        connection.commit()

        return redirect(url_for('show'))

    return render_template('editar_producto.html', producto=producto)

@app.route('/eliminar_producto/<int:codigo>')
def eliminar_producto(codigo):
    # Consultar la imagen_url del producto antes de eliminarlo
    cursor.execute('SELECT imagen_url FROM productos WHERE codigo = %s', (codigo,))
    imagen_url = cursor.fetchone()

    if imagen_url:
        # Eliminar la imagen asociada si existe
        ruta_imagen = os.path.join(app.config['UPLOAD_FOLDER'], imagen_url['imagen_url'])
        if os.path.exists(ruta_imagen):
            os.remove(ruta_imagen)

    # Eliminar el producto de la base de datos
    cursor.execute('DELETE FROM productos WHERE codigo = %s', (codigo,))
    connection.commit()

    return redirect(url_for('admin_dashboard'))

# iniciar aplicacion
if __name__ == '__main__':
    app.run(debug=True)