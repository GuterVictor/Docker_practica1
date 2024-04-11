#!/bin/bash

usuario="devops"
llave="ssh-ed25519"
permisos="devops   ALL=(ALL)      NOPASSWD:ALL"

if id -u $usuario >/dev/null 2>&1; then
    echo "El usuario $usuario ya existe"
else
    useradd $usuario
fi

if test -f /etc/sudoers.d/devops; then
    echo "El archivo /etc/sudoers.d/devops ya existe"
else
    touch /etc/sudoers.d/devops
    echo $permisos >> /etc/sudoers.d/devops
    chmod 440 /etc/sudoers.d/devops
fi

if id -u $usuario >/dev/null 2>&1; then
    su -l $usuario <<HEREDOC
    cd ~
    if [ ! -d ~/.ssh ]; then
        mkdir .ssh/
        chmod 700 .ssh/
        if [ ! -f ~/.ssh/authorized_keys ]; then
            touch .ssh/authorized_keys
            echo $llave >> .ssh/authorized_keys
            chmod 600 .ssh/authorized_keys
            exit
        else
            echo "El archivo ~/.ssh/authorized_keys ya existe"
        fi
    else
        echo "El directorio ~/.ssh ya existe"
    fi
HEREDOC
else
    echo "El usuario '$usuario' no existe."
fi
systemctl restart sshd