
#!/bin/bash

# Script para crear la topología completa - versión interactiva
# Añadir biblioteca de colores y formato
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
INFO="${BLUE}ℹ${NC}"
WARNING="${YELLOW}!${NC}"

# Variable para rastrear errores
errors=0

# Función para mostrar mensajes de estado
show_status() {
    local step=$1
    local message=$2
    local status=$3 # "success", "warning", "info" o "error"
    
    case $status in
        "success")
            echo -e " ${CHECK} ${step}: ${message}"
            ;;
        "warning")
            echo -e " ${WARNING} ${step}: ${message}"
            ;;
        "info")
            echo -e " ${INFO} ${step}: ${message}"
            ;;
        "error")
            echo -e " ${CROSS} ${step}: ${message}"
            ((errors++))
            ;;
        *)
            echo -e " ${INFO} ${step}: ${message}"
            ;;
    esac
}

# Función para verificar la existencia de VMs
vm_exists() {
    local worker=$1
    local vm_name=$2
    
    # Intenta obtener el estado de la VM
    result=$(ssh ubuntu@$worker "sudo virsh domstate $vm_name 2>/dev/null" 2>/dev/null)
    
    # Si el resultado contiene "running", la VM existe y está ejecutándose
    if [[ $result == *"running"* ]]; then
        return 0  # VM existe y está ejecutándose
    else
        # Intenta verificar si la VM está definida pero no ejecutándose
        result=$(ssh ubuntu@$worker "sudo virsh list --all | grep $vm_name" 2>/dev/null)
        if [[ ! -z $result ]]; then
            return 1  # VM existe pero no está ejecutándose
        else
            return 2  # VM no existe
        fi
    fi
}
clear
echo -e "\n${BLUE}=========================================================${NC}"
echo -e "${BLUE}         ORQUESTADOR DE REDES CLOUD - PUCP TEL141         ${NC}"
echo -e "${BLUE}=========================================================${NC}\n"

echo -e "${GREEN}Verificando la topología existente...${NC}\n"

# Configuración de nodos
echo -e "${YELLOW}Configuración de la topología:${NC}"
HEAD_NODE="localhost"
WORKER1="10.0.10.2"
WORKER2="10.0.10.3"
WORKER3="10.0.10.4"
OFS_NODE="10.0.10.5"

echo -e " • HeadNode: ${HEAD_NODE}"
echo -e " • Workers: ${WORKER1}, ${WORKER2}, ${WORKER3}"
echo -e " • OFS: ${OFS_NODE}\n"

# Configuración de interfaces
HEAD_INTERNET_IFACE="ens3"
HEAD_OFS_IFACE="ens4"
WORKER_OFS_IFACE="ens4"

# Configuración de VLANs
echo -e "${YELLOW}Configuración de redes:${NC}"
VLAN_IDS=("100" "200" "300")
VLAN_NETWORKS=("192.168.10.0/24" "192.168.20.0/24" "192.168.30.0/24")
for i in "${!VLAN_IDS[@]}"; do
    echo -e " • VLAN ${VLAN_IDS[$i]}: Red ${VLAN_NETWORKS[$i]}"
done
echo ""
# Paso 1: Verificar el HeadNode
echo -e "${YELLOW}Paso 1/6: Verificando HeadNode...${NC}"
# Comprobar si el bridge ya existe
if ovs-vsctl show | grep -q "Bridge \"br-int\""; then
    show_status "HeadNode" "Bridge br-int ya configurado" "success"
else
    show_status "HeadNode" "Bridge br-int no existe, creando..." "info"
    ./initialize_headnode.sh br-int $HEAD_OFS_IFACE >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        show_status "HeadNode" "Inicializado correctamente" "success"
    else
        show_status "HeadNode" "Error durante la inicialización" "error"
    fi
fi
echo ""

# Paso 2: Verificar el nodo OFS
echo -e "${YELLOW}Paso 2/6: Verificando nodo OFS...${NC}"
# Comprobar si el bridge ya existe en OFS
if ssh ubuntu@$OFS_NODE "ovs-vsctl show" 2>/dev/null | grep -q "Bridge \"br-int\""; then
    show_status "OFS" "Bridge br-int ya configurado" "success"
else
    show_status "OFS" "Bridge br-int no existe, creando..." "info"
    ssh ubuntu@$OFS_NODE "sudo bash -s" < initialize_worker.sh br-int ens5 ens6 ens7 ens8 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        show_status "OFS" "Inicializado correctamente" "success"
    else
        show_status "OFS" "Error durante la inicialización" "error"
    fi
fi
echo ""

# Paso 3: Verificar los Workers
echo -e "${YELLOW}Paso 3/6: Verificando Workers...${NC}"
for worker in $WORKER1 $WORKER2 $WORKER3; do
    if ssh ubuntu@$worker "ovs-vsctl show" 2>/dev/null | grep -q "Bridge \"br-int\""; then
        show_status "Worker ${worker}" "Bridge br-int ya configurado" "success"
    else
        show_status "Worker ${worker}" "Bridge br-int no existe, creando..." "info"
        ssh ubuntu@$worker "sudo bash -s" < initialize_worker.sh br-int $WORKER_OFS_IFACE >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            show_status "Worker ${worker}" "Inicializado correctamente" "success"
        else
            show_status "Worker ${worker}" "Error durante la inicialización" "error"
        fi
    fi
done
echo ""

# Paso 4: Verificar las redes VLAN
echo -e "${YELLOW}Paso 4/6: Verificando redes VLAN...${NC}"
for i in "${!VLAN_IDS[@]}"; do
    VLAN_ID=${VLAN_IDS[$i]}
    VLAN_NETWORK=${VLAN_NETWORKS[$i]}
    VLAN_DHCP_RANGE="192.168.${VLAN_ID:0:2}.10,192.168.${VLAN_ID:0:2}.200"
    
    # Comprobar si la interfaz VLAN ya existe
    if ip link show | grep -q "vlan${VLAN_ID}"; then
        show_status "VLAN ${VLAN_ID}" "Interfaz vlan${VLAN_ID} ya configurada" "success"
    else
        show_status "VLAN ${VLAN_ID}" "Interfaz vlan${VLAN_ID} no existe, creando..." "info"
        ./create_network.sh vlan$VLAN_ID $VLAN_ID $VLAN_NETWORK $VLAN_DHCP_RANGE >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            show_status "VLAN ${VLAN_ID}" "Creada correctamente" "success"
        else
            show_status "VLAN ${VLAN_ID}" "Error al crear la red" "error"
        fi
    fi
    
    # Verificar reglas de iptables para Internet
    if sudo iptables -t nat -C POSTROUTING -o $HEAD_INTERNET_IFACE -s $VLAN_NETWORK -j MASQUERADE 2>/dev/null; then
        show_status "Internet VLAN ${VLAN_ID}" "Acceso a Internet ya configurado" "success"
    else
        show_status "Internet VLAN ${VLAN_ID}" "Configurando acceso a Internet..." "info"
        sudo ./internet_access.sh $VLAN_ID $HEAD_INTERNET_IFACE >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            show_status "Internet VLAN ${VLAN_ID}" "Configurado correctamente" "success"
        else
            show_status "Internet VLAN ${VLAN_ID}" "Error al configurar acceso a Internet" "error"
        fi
    fi
done
echo ""

# Paso 5: Verificar comunicación entre VLANs
echo -e "${YELLOW}Paso 5/6: Verificando comunicación entre VLANs...${NC}"
# Verificar si ya existe la regla entre VLAN 100 y 200
if sudo iptables -C FORWARD -i vlan100 -o vlan200 -j ACCEPT 2>/dev/null && \
   sudo iptables -C FORWARD -i vlan200 -o vlan100 -j ACCEPT 2>/dev/null; then
    show_status "VLAN 100 <-> 200" "Comunicación ya configurada" "success"
else
    show_status "VLAN 100 <-> 200" "Configurando comunicación..." "info"
    sudo ./connect_vlans.sh 100 200 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        show_status "VLAN 100 <-> 200" "Comunicación habilitada" "success"
    else
        show_status "VLAN 100 <-> 200" "Error al configurar comunicación" "warning"
    fi
fi
echo ""

# Paso 6: Verificar VMs en los Workers
echo -e "${YELLOW}Paso 6/6: Verificando VMs en los Workers...${NC}"

PUCP_CODE="20:18:59:10"

# Lista de VMs a verificar
declare -A VM_INFO
VM_INFO["vm1-w1-v1"]="$WORKER1,100,1,${PUCP_CODE}:ee:01"
VM_INFO["vm2-w1-v2"]="$WORKER1,200,2,${PUCP_CODE}:ee:02"
VM_INFO["vm3-w1-v3"]="$WORKER1,300,3,${PUCP_CODE}:ee:03"
VM_INFO["vm1-w2-v1"]="$WORKER2,100,1,${PUCP_CODE}:ee:04"
VM_INFO["vm2-w2-v2"]="$WORKER2,200,2,${PUCP_CODE}:ee:05"
VM_INFO["vm3-w2-v3"]="$WORKER2,300,3,${PUCP_CODE}:ee:06"
VM_INFO["vm1-w3-v1"]="$WORKER3,100,1,${PUCP_CODE}:ee:07"
VM_INFO["vm2-w3-v2"]="$WORKER3,200,2,${PUCP_CODE}:ee:08"
VM_INFO["vm3-w3-v3"]="$WORKER3,300,3,${PUCP_CODE}:ee:09"

# Verificar VMs en Worker 1
echo -e "${BLUE}Worker ${WORKER1}:${NC}"
for vm in "vm1-w1-v1" "vm2-w1-v2" "vm3-w1-v3"; do
    IFS=',' read -r worker vlan_id port mac <<< "${VM_INFO[$vm]}"
    vm_exists $worker $vm
    status=$?
    
    if [ $status -eq 0 ]; then
        show_status "VM $vm" "Ya existe y está ejecutándose" "success"
    elif [ $status -eq 1 ]; then
        show_status "VM $vm" "Existe pero no está ejecutándose, iniciando..." "info"
        ssh ubuntu@$worker "sudo virsh start $vm" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            show_status "VM $vm" "Iniciada correctamente" "success"
        else
            show_status "VM $vm" "Error al iniciar la VM" "error"
        fi
    else
        show_status "VM $vm" "No existe, creando..." "info"
        ssh ubuntu@$worker "sudo bash -s" < create_vm.sh $vm br-int $vlan_id $port "$mac" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            show_status "VM $vm" "Creada e iniciada correctamente" "success"
        else
            show_status "VM $vm" "Error al crear la VM" "error"
        fi
    fi
done

# Verificar VMs en Worker 2
echo -e "${BLUE}Worker ${WORKER2}:${NC}"
for vm in "vm1-w2-v1" "vm2-w2-v2" "vm3-w2-v3"; do
    IFS=',' read -r worker vlan_id port mac <<< "${VM_INFO[$vm]}"
    vm_exists $worker $vm
    status=$?
    
    if [ $status -eq 0 ]; then
        show_status "VM $vm" "Ya existe y está ejecutándose" "success"
    elif [ $status -eq 1 ]; then
        show_status "VM $vm" "Existe pero no está ejecutándose, iniciando..." "info"
        ssh ubuntu@$worker "sudo virsh start $vm" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            show_status "VM $vm" "Iniciada correctamente" "success"
        else
            show_status "VM $vm" "Error al iniciar la VM" "error"
        fi
    else
        show_status "VM $vm" "No existe, creando..." "info"
        ssh ubuntu@$worker "sudo bash -s" < create_vm.sh $vm br-int $vlan_id $port "$mac" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            show_status "VM $vm" "Creada e iniciada correctamente" "success"
        else
            show_status "VM $vm" "Error al crear la VM" "error"
        fi
    fi
done

# Verificar VMs en Worker 3
echo -e "${BLUE}Worker ${WORKER3}:${NC}"
for vm in "vm1-w3-v1" "vm2-w3-v2" "vm3-w3-v3"; do
    IFS=',' read -r worker vlan_id port mac <<< "${VM_INFO[$vm]}"
    vm_exists $worker $vm
    status=$?
    
    if [ $status -eq 0 ]; then
        show_status "VM $vm" "Ya existe y está ejecutándose" "success"
    elif [ $status -eq 1 ]; then
        show_status "VM $vm" "Existe pero no está ejecutándose, iniciando..." "info"
        ssh ubuntu@$worker "sudo virsh start $vm" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            show_status "VM $vm" "Iniciada correctamente" "success"
        else
            show_status "VM $vm" "Error al iniciar la VM" "error"
        fi
    else
        show_status "VM $vm" "No existe, creando..." "info"
        ssh ubuntu@$worker "sudo bash -s" < create_vm.sh $vm br-int $vlan_id $port "$mac" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            show_status "VM $vm" "Creada e iniciada correctamente" "success"
        else
            show_status "VM $vm" "Error al crear la VM" "error"
        fi
    fi
done
echo ""

# Resumen final
echo -e "\n"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✓ Verificación de topología completada con éxito${NC}\n"
else
    echo -e "${YELLOW}! Verificación de topología completada con $errors errores${NC}\n"
fi


echo -e "${YELLOW}RESUMEN DE LA TOPOLOGÍA:${NC}"
echo -e " • 3 redes VLAN (100, 200, 300) con acceso a Internet"
echo -e " • Comunicación habilitada entre VLANs 100 y 200"
echo -e " • 9 VMs desplegadas en 3 Workers:"
echo -e "   - VLAN 100: vm1-w1-v1, vm1-w2-v1, vm1-w3-v1"
echo -e "   - VLAN 200: vm2-w1-v2, vm2-w2-v2, vm2-w3-v2"
echo -e "   - VLAN 300: vm3-w1-v3, vm3-w2-v3, vm3-w3-v3"
echo -e "\n${BLUE}Acceso a VMs vía VNC:${NC}"
echo -e " • Para Worker 1 (${WORKER1}):"
echo -e "   ssh -L 15901:localhost:5901 -L 15902:localhost:5902 -L 15903:localhost:5903 ubuntu@10.20.12.180 -p 580>
echo -e "   - VNC: localhost:15901, localhost:15902, localhost:15903"
echo -e " • Para Worker 2 (${WORKER2}):"
echo -e "   ssh -L 25901:localhost:5901 -L 25902:localhost:5902 -L 25903:localhost:5903 ubuntu@10.20.12.180 -p 580>
echo -e "   - VNC: localhost:25901, localhost:25902, localhost:25903"
echo -e " • Para Worker 3 (${WORKER3}):"
echo -e "   ssh -L 35901:localhost:5901 -L 35902:localhost:5902 -L 35903:localhost:5903 ubuntu@10.20.12.180 -p 580>
echo -e "   - VNC: localhost:35901, localhost:35902, localhost:35903"
echo -e "\n${BLUE}=========================================================${NC}"
