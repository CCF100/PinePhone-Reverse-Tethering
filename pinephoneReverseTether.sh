#/bin/bash
# https://stackoverflow.com/a/32708121
# A prompt confirm function.
prompt_confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input"
    esac 
  done  
}
# Get array of interfaces
interfaces=()
for iface in $(ifconfig | cut -d ' ' -f1| tr ':' '\n' | awk NF)
do
        #printf "$iface\n"
        interfaces+=("$iface")
done
#echo ${interfaces[@]}
echo "${#interfaces[@]} interfaces detected!"
# This function prompts the user to select an interface.
function determine_interface() {
    local prompt=$1
    #local $INTERFACE_RETURN
    echo -e "\e[1m$prompt\e[0m" >&2
    select INTERFACE_RETURN in ${interfaces[@]}; do
        prompt_confirm "Select $INTERFACE_RETURN"?; break
    done
    printf "$INTERFACE_RETURN"
}
get_ip() {
    printf "$(ip -o -4 addr list $1 | awk '{print $4}' | cut -d/ -f1)"
    #"$(ip addr show $1| awk '/inet /{print substr($2,1)}' | awk '{print substr($1, 1, length($1)-3)}')"
}

INTERNET_FACING_INTERFACE=$(determine_interface "Select the interface that is exposed to the internet:")
echo "$INTERNET_FACING_INTERFACE selected as internet facing interface"
echo "IP address of $INTERNET_FACING_INTERFACE is $(get_ip $INTERNET_FACING_INTERFACE)"
PINEPHONE_FACING_INTERFACE=$(determine_interface "Select the interface that is created by the PinePhone's tether script:")
echo "$PINEPHONE_FACING_INTERFACE selected as PinePhone facing interface"
echo "IP address of $PINEPHONE_FACING_INTERFACE is $(get_ip $PINEPHONE_FACING_INTERFACE)"

echo "Setting IP Tables... (will prompt for password multiple times)"
sudo iptables -t nat -A POSTROUTING -o $INTERNET_FACING_INTERFACE -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i $PINEPHONE_FACING_INTERFACE -o $INTERNET_FACING_INTERFACE -j ACCEPT
echo "IP Tables set!"
echo "Attempting to set default route on PinePhone..."
echo "NOTE: Due to the fact we're running sudo in ssh without a shell, sudo is unable to hide your password! Make sure no one's looking at your screen before continuing!"
ssh 10.15.19.82 sudo -S ip route add default via $(get_ip $PINEPHONE_FACING_INTERFACE) dev usb0; echo "Success!"
