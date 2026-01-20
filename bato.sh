#!/bin/bash

# BATOSINE v2.1 - SOC DARK MONITOR
# Thème : Fond Noir | Texte Blanc | Progress Blanc

if [[ $EUID -ne 0 ]]; then
   echo "ERREUR : Lancez le script avec 'sudo'."
   exit 1
fi

PIPE=$(mktemp -u --tmpdir batosine_pipe.XXXXX)
mkfifo "$PIPE"
exec 3<> "$PIPE"

# --- FONCTION : BARRE DE PROGRESSION BLANCHE ---
get_graph() {
    local val=$1
    local bars=$((val / 10))
    local graph=""
    # Couleur blanche pour la barre de progression
    local color="#FFFFFF"
    for ((i=0; i<10; i++)); do
        if [ $i -lt $bars ]; then 
            graph+="<span foreground='$color'>■</span>"
        else 
            graph+="<span foreground='#444444'>□</span>"
        fi
    done
    echo "$graph"
}

# --- FONCTION : COLLECTE ---
collect_data() {
    echo -e '\f' >&3
    
    ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | \
    grep -vE "ps|grep|awk|yad|bash|sudo" | grep -v "\[.*\]" | \
    head -n 40 | tail -n +2 | \
    while read -r pid user cpu mem comm; do
        
        cpu_val=${cpu%.*}
        graph=$(get_graph "$cpu_val")
        
        # Logique de couleur pour le PID et le %
        color_status="#00FF00"
        [ "$cpu_val" -gt 40 ] && color_status="#FFA500"
        [ "$cpu_val" -gt 80 ] && color_status="#FF0000"
        
        # Envoi des données stylisées
        echo -e "<span foreground='$color_status'>$pid</span>" >&3
        echo -e "<span foreground='#FFFFFF' weight='bold'>$user</span>" >&3 # Nom utilisateur en BLANC
        echo -e "<span foreground='$color_status' weight='bold'>$cpu%</span>" >&3
        echo -e "$graph" >&3 # Barre de progression BLANCHE
        echo -e "<span foreground='#FFFFFF'>$mem%</span>" >&3
        echo -e "<span foreground='#3498db'><b>$comm</b></span>" >&3
    done
}

# --- BOUCLE DE MISE À JOUR ---
(
    while [ -p "$PIPE" ]; do
        collect_data
        sleep 4
    done
) &
COLLECTOR_PID=$!

# --- INTERFACE NOIRE ---
# On utilise GTK_THEME pour forcer le mode sombre si possible
# Et les options de YAD pour le style de la liste
selected_row=$(GTK_THEME=Adwaita:dark yad --list \
    --title="BATOSINE - Moniteur Système" \
    --width=1200 --height=900 --center \
    --window-icon="security-high" \
    --text="Suivi des processus" \
    --column="Pid":MARKUP --column="Utilisateur":MARKUP \
    --column="Cpu":MARKUP --column="Charge":MARKUP \
    --column="Ram":MARKUP --column="Processus":MARKUP \
    --search-column=6 \
    --dclick-action="bash -c 'lsof -p %s | yad --text-info --width=800 --height=600 --title=\"Fichiers Ouverts\"'" \
    --button="⏸ Stop:10" \
    --button="▶ Restart:11" \
    --button="💀 Kill:12" \
    --listen <&3)

ACTION_CODE=$?

kill $COLLECTOR_PID 2>/dev/null
rm -f "$PIPE"

# --- ACTIONS & CONFIRMATION ---
if [ -n "$selected_row" ]; then
    PID=$(echo "$selected_row" | awk -F'|' '{print $1}' | sed 's/<[^>]*>//g' | tr -d ' ')
    COMM=$(echo "$selected_row" | awk -F'|' '{print $6}' | sed 's/<[^>]*>//g')

    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        # Fenêtre de confirmation conforme à image_adb0a3.png
        GTK_THEME=Adwaita:dark yad --image="dialog-warning" --title="ADMIN - Confirmation" \
            --text="Voulez-vous vraiment agir sur <b>$COMM</b> (PID: $PID) ?" \
            --button="Annuler:1" --button="Confirmer:0" --center
        
        if [ $? -eq 0 ]; then
            case $ACTION_CODE in
                10) kill -STOP "$PID" ;;
                11) kill -CONT "$PID" ;;
                12) kill -9 "$PID" ;;
            esac
        fi
    fi
    exec "$0"
fi
