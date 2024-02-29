<?php

if (isset($_POST['user'])) {
  $usuario = $_POST['user'];

  if (ctype_alnum($usuario)) {
    echo "El usuario es válido";
  } else {
    echo "El usuario no es válido.";
  }
}

?>
