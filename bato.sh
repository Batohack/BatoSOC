#!/bin/bash



if [[ $EUID -ne 0 ]]; then
   echo "ERREUR : Lancez le script avec 'sudo'."
   exit 1
fi

PIPE=$(mktemp -u --tmpdir batosine_pipe.XXXXX)
mkfifo "$PIPE"

# --- FONCTION DE COLLECTE ET STYLISATION ---
collect_data() {
    echo -e '\f' > "$PIPE"
    
    ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | \
    grep -vE "ps|grep|awk|yad|bash|dirname|sudo" | \
    grep -v "\[.*\]" | \
    head -n 31 | tail -n +2 | \
    while read -r pid user cpu mem comm; do
        
        pid=$(echo "$pid" | tr -d ' ')
        cpu_val=${cpu%.*}
        
        # Styles de couleurs HEX
        color_ok="#00FF00"
        color_warn="#FFA500"
        color_danger="#FF0000"
        
        if [ "$cpu_val" -gt 80 ]; then
            status="<span foreground='$color_danger' weight='bold'>🔴 DANGER</span>"
            row_style="<span foreground='$color_danger' weight='bold'>"
        elif [ "$cpu_val" -gt 40 ]; then
            status="<span foreground='$color_warn'>🟠 ALERTE</span>"
            row_style="<span foreground='$color_warn'>"
        else
            status="<span foreground='$color_ok'>🟢 OK</span>"
            row_style="<span>"
        fi
        
        end="</span>"

        # Envoi des colonnes avec style
        echo -e "$status" > "$PIPE"
        echo -e "$row_style$pid$end" > "$PIPE"
        echo -e "$row_style$user$end" > "$PIPE"
        echo -e "$row_style$cpu%$end" > "$PIPE"
        echo -e "$row_style$mem%$end" > "$PIPE"
        echo -e "<b>$comm</b>" > "$PIPE"
    done
}

# 2. Boucle Principale
while true; do
    (
        while [ -p "$PIPE" ]; do
            collect_data
            sleep 4
        done
    ) &
    COLLECTOR_PID=$!

    # Correction de l'erreur : ajout de </b> à la fin du texte
    selected_row=$(yad --list \
        --title="BATOSINE - SOC Monitor" \
        --width=1100 --height=850 --center \
        --window-icon="security-high" \
        --text="<b>Suivi des Processus SOC - Surveillance Active</b>" \
        --column="Statut":MARKUP \
        --column="PID":NUM \
        --column="User":MARKUP \
        --column="%Cpu":MARKUP \
        --column="%Ram":MARKUP \
        --column="Nom":MARKUP \
        --button="⏸ Stop:10" \
        --button="▶ Restart:11" \
        --button="💀 Kill:12" \
        --listen < "$PIPE")
    
    ACTION_CODE=$?

    kill $COLLECTOR_PID 2>/dev/null
    wait $COLLECTOR_PID 2>/dev/null

    if [ $ACTION_CODE -eq 252 ] || [ $ACTION_CODE -eq 1 ]; then
        rm -f "$PIPE"
        exit 0
    fi

    # Extraction du PID en ignorant les balises de style
    PID=$(echo "$selected_row" | awk -F'|' '{print $2}' | sed 's/<[^>]*>//g' | tr -d ' ')

    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        case $ACTION_CODE in
            10) kill -STOP "$PID" ;;
            11) kill -CONT "$PID" ;;
            12) kill -9 "$PID" ;;
        esac
    fi
done
