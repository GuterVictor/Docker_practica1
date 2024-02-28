<!DOCTYPE html>
<html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Login</title>
    </head>
    <body>
        <h3>Autenticación</h3>
        <form action="envio.php" method="POST">
            
            <p><label for="user">Usuario</label>
            <input type="text" name="user"></p>

            <p><label for="passw">Contraseña</label>
            <input type="password" name="passw"></p>

            <input type="checkbox" name="recordar">
            <label>Recordarme</label>

            <p><input type="submit" value="Entrar">
        </form>
    </body>
</html>