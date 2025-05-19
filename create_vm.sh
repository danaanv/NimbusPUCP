#!/bin/bash

# Script para crear VMs con soporte para VLANs por conexión
# Uso: ./create_vm.sh <vm_name> <bridge> <vlan_id> <vnc_port> [mac_address]


if [ $# -lt 4 ]; then
    echo "Uso: $0 <vm_name> <bridge> <vlan_id> <vnc_port> [mac_address]"
    echo "Ejemplo: $0 vm1 br-int 100 1 52:54:00:01:01:01"
    exit 1
fi

VM_NAME=$1
BRIDGE=$2
VLAN_ID=$3
VNC_PORT=$4
MAC_ADDRESS=$5

if [ -z "$MAC_ADDRESS" ]; then
    PREFIX="52:54:00"
    SUFFIX=$(echo -n "$VM_NAME" | md5sum | cut -c1-6 | sed 's/\(..\)/\1:/g' | sed 's/:$//')
    MAC_ADDRESS="${PREFIX}:${SUFFIX}"
fi

echo "Creando VM $VM_NAME en puente $BRIDGE con VLAN $VLAN_ID, VNC en puerto $VNC_PORT y MAC $MAC_ADDRESS"

CURRENT_DIR=$(pwd)
IMAGES_DIR="$CURRENT_DIR/images"
BASE_IMAGE="$IMAGES_DIR/ubuntu-22.04-minimal.qcow2"
VM_IMAGE="$IMAGES_DIR/$VM_NAME.qcow2"

mkdir -p "$IMAGES_DIR"

if [ ! -f "$BASE_IMAGE" ]; then
    echo "Imagen base $BASE_IMAGE no encontrada. Descargando..."
    
    
    IMAGE_URL="https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img"
    
  
    wget -O "$BASE_IMAGE" "$IMAGE_URL"
    
    if [ $? -ne 0 ]; then
        echo "Error al descargar la imagen base. Por favor, verifique la conexión a Internet."
        ALTERNATIVE_URL="https://cloud-images.ubuntu.com/minimal/releases/jammy/release-20230624/ubuntu-22.04-minimal-cloudimg-amd64.img"
        echo "Intentando con URL alternativa: $ALTERNATIVE_URL"
        wget -O "$BASE_IMAGE" "$ALTERNATIVE_URL"
        
        if [ $? -ne 0 ]; then
            echo "Error al descargar la imagen alternativa. Verificando imágenes locales..."
            
            SYSTEM_IMAGES=$(find /var/lib/libvirt/images -name "*.qcow2" | head -1)
            if [ -n "$SYSTEM_IMAGES" ]; then
                echo "Usando imagen local: $SYSTEM_IMAGES"
                cp "$SYSTEM_IMAGES" "$BASE_IMAGE"
            else
                echo "No se encontraron imágenes locales. Abortando."
                exit 1
            fi
        fi
    fi
    
    echo "Imagen base descargada correctamente en $BASE_IMAGE"
    
   
    qemu-img resize "$BASE_IMAGE" +5G
    echo "Imagen redimensionada a 5GB adicionales"
fi


if [ ! -f "$VM_IMAGE" ]; then
    echo "Creando imagen para $VM_NAME..."
    qemu-img create -f qcow2 -b "$BASE_IMAGE" "$VM_IMAGE" 10G
    echo "Imagen creada: $VM_IMAGE"
else
    echo "La imagen $VM_IMAGE ya existe."
fi

HOSTNAME=$(hostname)

# Configurar el archivo XML para la VM
VM_XML=$(mktemp)

cat > $VM_XML << EOF
<domain type='kvm'>
  <name>$VM_NAME</name>
  <memory unit='MiB'>512</memory>
  <vcpu placement='static'>1</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-5.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-model'/>
  <clock offset='utc'/>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='$VM_IMAGE'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='bridge'>
      <source bridge='$BRIDGE'/>
      <virtualport type='openvswitch'/>
      <target dev='vnet-$VM_NAME'/>
      <model type='virtio'/>
      <mac address='$MAC_ADDRESS'/>
      <vlan>
        <tag id='$VLAN_ID'/>
      </vlan>
    </interface>
    <serial type='pty'>
      <target type='isa-serial' port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <graphics type='vnc' port='59${VNC_PORT}0' autoport='no' listen='0.0.0.0'>
      <listen type='address' address='0.0.0.0'/>
    </graphics>
    <video>
      <model type='vga' vram='16384' heads='1' primary='yes'/>
    </video>
  </devices>
</domain>
EOF

# Definir la VM
virsh define $VM_XML

# Iniciar la VM
virsh start $VM_NAME

# Limpiar archivos temporales
rm $VM_XML

echo "VM $VM_NAME creada e iniciada con éxito en VLAN $VLAN_ID."
echo "Puedes acceder a la consola VNC en: $HOSTNAME:59${VNC_PORT}0"


virsh dominfo $VM_NAME

exit 0