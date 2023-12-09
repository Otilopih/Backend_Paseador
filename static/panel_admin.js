function confirmarEliminacion(codigo) {
    var confirmacion = confirm("¿Estás seguro de que deseas eliminar este producto?");
    if (confirmacion) {
        window.location.href = "/eliminar_producto/" + codigo;
    }
    return false; // Evita que el enlace siga su comportamiento predeterminado
}